# Query params used for navigation context:
#
#   from_edit   — "User entered from the hub's Edit button." Set only by the
#                 hub edit link. Threads through the flow so the review page
#                 shows "Save changes" and hides the back button.
#
#   from_review — "User clicked Edit on the review page to fix one thing."
#                 Set by edit links on the review page. Tells controllers to
#                 redirect back to review instead of advancing forward.
class Activities::EducationController < Activities::BaseController
  # Keep the user on the loading page (the #show action) at least this long.
  ARTIFICIAL_DELAY = 7.seconds
  INDICATOR_COUNT = 3

  before_action :set_education_activity, only: %i[show edit update destroy review save_review]
  before_action :set_back_url, only: %i[edit review]

  def verify
    @identity = current_identity!
  end

  def create
    if params[:education_activity]
      create_fully_self_attested_activity
    else
      create_validated_activity
    end
  end

  def show
    @polling_url = activities_flow_education_sync_path(education_id: @education_activity.id)

    set_completed_indicators

    if @education_activity.sync_failed? || @education_activity.sync_no_enrollments?
      redirect_to activities_flow_education_error_path
    elsif @education_activity.sync_succeeded? && !testing_synchronization_page?
      redirect_to education_sync_success_path
    else
      # sync is still in progress — render the polling page
    end
  end

  def update
    if @education_activity.fully_self_attested?
      if @education_activity.update(fully_self_attested_education_params)
        if params[:from_review].present?
          redirect_to review_activities_flow_education_path(id: @education_activity, from_edit: params[:from_edit].presence)
        else
          redirect_to edit_activities_flow_education_month_path(education_id: @education_activity, id: 0, from_edit: params[:from_edit].presence)
        end
      else
        render :edit_fully_self_attested, status: :unprocessable_content
      end
    elsif @education_activity.update(education_params)
      if @education_activity.has_less_than_half_time_terms?
        redirect_to edit_activities_flow_education_term_credit_hour_path(
          education_id: @education_activity, id: 0
        )
      else
        redirect_to after_activity_path
      end
    else
      redirect_to :edit, flash: { alert: t("activities.education.errors.unexpected") }
    end
  end

  def edit
    render :edit_fully_self_attested if @education_activity.fully_self_attested?
  end

  def destroy
    @education_activity.destroy

    redirect_to activities_flow_root_path
  end

  def sync
    @education_activity = @flow.education_activities.find(params[:education_id])

    set_completed_indicators

    if @education_activity.sync_unknown?
      render turbo_stream: turbo_stream.replace(:synchronization, partial: "status")
    elsif @education_activity.sync_failed? || @education_activity.sync_no_enrollments?
      render turbo_stream: turbo_stream.action(:redirect, activities_flow_education_error_path)
    elsif @wait_time < ARTIFICIAL_DELAY && !testing_synchronization_page?
      render turbo_stream: turbo_stream.replace(:synchronization, partial: "status")
    else
      render turbo_stream: turbo_stream.action(:redirect, education_sync_success_path)
    end
  end

  def new
    @education_activity = @flow.education_activities.new
  end

  def review
  end

  def save_review
    @education_activity.update(review_params)
    redirect_to @education_activity.fully_self_attested? ? activities_flow_root_path : after_activity_path
  end

  def error
  end

  private

  def set_education_activity
    @education_activity = @flow.education_activities.find(params[:id])
  end

  def set_back_url
    case action_name
    when "edit"
      if params[:from_review].present?
        @back_url = review_activities_flow_education_path(
          id: @education_activity,
          from_edit: params[:from_edit].presence
        )
      end
    when "review"
      unless params[:from_edit].present?
        @back_url = new_activities_flow_education_document_upload_path(
          education_id: @education_activity
        )
      end
    end
  end

  def review_params
    params.require(:education_activity).permit(:additional_comments)
  end

  def education_params
    params
      .require(:education_activity)
      .permit(
        :id,
        :additional_comments,
        :credit_hours
      )
  end

  def fully_self_attested_education_params
    params.require(:education_activity).permit(
      :school_name, :street_address, :street_address_line_2,
      :city, :state, :zip_code,
      :contact_name, :contact_email, :contact_phone_number
    )
  end

  def set_completed_indicators
    if @education_activity.sync_unknown?
      @completed_indicators = INDICATOR_COUNT.times.map { |i| false }
    else
      @wait_time = Time.now - @education_activity.created_at
      @completed_indicators = INDICATOR_COUNT.times.map { |i| @wait_time > ((ARTIFICIAL_DELAY - 1) / INDICATOR_COUNT * (i + 1)) }
    end
  end

  # In order to test the behavior of the /synchronization page in E2E tests, we
  # want to disable the artificial delay and ensure the page always shows even
  # if the synchronization actually happens immediately.
  def testing_synchronization_page?
    Rails.env.test?
  end

  def after_education_update_path
    if params[:from_review].present?
      review_activities_flow_education_path(id: @education_activity, from_edit: params[:from_edit].presence)
    elsif @education_activity.partially_self_attested?
      partially_self_attested_education_next_step_path
    else
      after_activity_path
    end
  end

  def partially_self_attested_education_next_step_path
    if @education_activity.has_less_than_half_time_terms?
      edit_activities_flow_education_term_credit_hour_path(
        education_id: @education_activity.id,
        id: 0
      )
    else
      new_activities_flow_education_document_upload_path(
        education_id: @education_activity.id,
        from_edit: params[:from_edit].presence
      )
    end
  end

  def create_fully_self_attested_activity
    @education_activity = @flow.education_activities.new(fully_self_attested_education_params)
    @education_activity.data_source = :fully_self_attested
    if @education_activity.save
      redirect_to edit_activities_flow_education_month_path(education_id: @education_activity, id: 0)
    else
      render :new, status: :unprocessable_content
    end
  end

  def create_validated_activity
    @education_activity = @flow.education_activities.create
    NscSynchronizationJob.perform_later(@education_activity.id)
    redirect_to activities_flow_education_path(id: @education_activity.id)
  end

  def education_sync_success_path
    if @education_activity.partially_self_attested?
      partially_self_attested_education_next_step_path
    else
      edit_activities_flow_education_path(id: @education_activity)
    end
  end
end

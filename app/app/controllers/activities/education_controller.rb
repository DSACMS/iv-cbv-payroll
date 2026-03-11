class Activities::EducationController < Activities::BaseController
  # Keep the user on the loading page (the #show action) at least this long.
  ARTIFICIAL_DELAY = 7.seconds
  INDICATOR_COUNT = 3

  def verify
    @identity = current_identity!
  end

  def create
    if params[:education_activity]
      @education_activity = @flow.education_activities.new(self_attested_education_params)
      @education_activity.data_source = :self_attested
      if @education_activity.save
        redirect_to edit_activities_flow_education_month_path(education_id: @education_activity, id: 0)
      else
        render :new, status: :unprocessable_content
      end
    else
      @education_activity = @flow.education_activities.create
      NscSynchronizationJob.perform_later(@education_activity.id)
      redirect_to activities_flow_education_path(id: @education_activity.id)
    end
  end

  def show
    @education_activity = @flow.education_activities.find(params[:id])
    @polling_url = activities_flow_education_sync_path(education_id: @education_activity.id)

    set_completed_indicators

    if @education_activity.sync_failed? || @education_activity.sync_no_enrollments?
      redirect_to activities_flow_education_error_path
    elsif @education_activity.sync_succeeded? && !testing_synchronization_page?
      redirect_to edit_activities_flow_education_path(id: params[:id])
    else
      # sync is still in progress — render the polling page
    end
  end

  def update
    @education_activity = @flow.education_activities.find(params[:id])
    if @education_activity.self_attested?
      if @education_activity.update(self_attested_education_params)
        redirect_to edit_activities_flow_education_month_path(education_id: @education_activity, id: 0, from_edit: 1)
      else
        render :edit_self_attested, status: :unprocessable_content
      end
    elsif @education_activity.update(education_params)
      redirect_to after_activity_path
    else
      redirect_to :edit, flash: { alert: t("activities.education.errors.unexpected") }
    end
  end

  def edit
    @education_activity = @flow.education_activities.find_by(id: params[:id])
    unless @education_activity
      redirect_to(
        activities_flow_root_path,
        flash: { alert: t("activities.education.error_no_data") }
      )
      return
    end

    render :edit_self_attested if @education_activity.self_attested?
  end

  def destroy
    activity = @flow.education_activities.find(params[:id])
    activity.destroy

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
      render turbo_stream: turbo_stream.action(:redirect, edit_activities_flow_education_path(id: @education_activity))
    end
  end

  def new
    @education_activity = @flow.education_activities.new
  end

  def review
    @education_activity = @flow.education_activities.find(params[:id])
  end

  def save_review
    @education_activity = @flow.education_activities.find(params[:id])
    @education_activity.update(review_params)
    redirect_to @education_activity.self_attested? ? activities_flow_root_path : after_activity_path
  end

  def error
  end

  private

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

  def self_attested_education_params
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
end

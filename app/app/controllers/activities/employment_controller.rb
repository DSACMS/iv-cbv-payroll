# Query params used for navigation context:
#
#   from_edit   — "User entered from the hub's Edit button." Set only by the
#                 hub edit link. Threads through the flow so the review page
#                 shows "Save changes" and hides the back button.
#
#   from_review — "User clicked Edit on the review page to fix one thing."
#                 Set by edit links on the review page. Tells controllers to
#                 redirect back to review instead of advancing forward.
class Activities::EmploymentController < Activities::BaseController
  before_action :set_employment_activity, only: %i[edit update review save_review]
  before_action :ensure_review_ready, only: %i[review save_review]
  before_action :set_back_url, only: %i[edit review]

  def new
    @employment_activity = @flow.employment_activities.new
  end

  def create
    @employment_activity = @flow.employment_activities.new(employment_activity_params.merge(draft: true))
    if @employment_activity.save
      redirect_to edit_activities_flow_income_employment_month_path(employment_id: @employment_activity, id: 0)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @employment_activity.update(employment_activity_params)
      if params[:from_review].present?
        redirect_to review_activities_flow_income_employment_path(id: @employment_activity, from_edit: params[:from_edit].presence)
      else
        redirect_to edit_activities_flow_income_employment_month_path(
        employment_id: @employment_activity,
        id: 0,
        from_edit: params[:from_edit].presence
      )
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  def review
  end

  def save_review
    @employment_activity.update(review_params)
    redirect_to after_activity_path(@employment_activity)
  end

  private

  def ensure_review_ready
    if @employment_activity.employer_name.blank?
      redirect_to edit_activities_flow_income_employment_path(@employment_activity)
      return
    end

    reporting_months = @flow.reporting_months
    reporting_months.each_with_index do |month, index|
      unless @employment_activity.employment_activity_months.exists?(month: month.beginning_of_month)
        redirect_to edit_activities_flow_income_employment_month_path(
          employment_id: @employment_activity, id: index
        )
        return
      end
    end
  end

  def set_employment_activity
    @employment_activity = @flow.employment_activities.find(params[:id])
  end

  def set_back_url
    if action_name == "edit" && params[:from_review].present?
      @back_url = review_activities_flow_income_employment_path(
        id: @employment_activity,
        from_edit: params[:from_edit].presence
      )
    elsif action_name == "review" && params[:from_edit].blank?
      last_month_index = @flow.reporting_months.length - 1
      @back_url = edit_activities_flow_income_employment_month_path(
        employment_id: @employment_activity,
        id: last_month_index
      )
    end
  end

  def review_params
    params.require(:employment_activity).permit(:additional_comments)
  end

  def employment_activity_params
    params.require(:employment_activity).permit(
      :employer_name, :street_address, :street_address_line_2,
      :city, :state, :zip_code,
      :is_self_employed, :contact_name, :contact_email, :contact_phone_number
    )
  end
end

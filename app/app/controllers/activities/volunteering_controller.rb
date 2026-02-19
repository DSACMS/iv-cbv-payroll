class Activities::VolunteeringController < Activities::BaseController
  before_action :set_volunteering_activity, only: %i[edit update destroy hours_input save_hours review save_review]

  include MonthlyHoursInput

  def new
    @volunteering_activity = @flow.volunteering_activities.new
  end

  def create
    @volunteering_activity = @flow.volunteering_activities.new(volunteering_activity_params)
    if @volunteering_activity.save
      redirect_to hours_input_activities_flow_volunteering_path(id: @volunteering_activity, month_index: 0)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @volunteering_activity.update(volunteering_activity_params)
      redirect_to hours_input_activities_flow_volunteering_path(id: @volunteering_activity, month_index: 0)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def review
  end

  def save_review
    @volunteering_activity.update(review_params)
    redirect_to after_activity_path, notice: t("activities.community_service.created")
  end

  def destroy
    @volunteering_activity.destroy

    redirect_to activities_flow_root_path, notice: t("activities.community_service.deleted")
  end

  private

  def set_volunteering_activity
    @volunteering_activity = @flow.volunteering_activities.find(params[:id])
  end

  # MonthlyHoursInput config methods

  def hours_input_activity
    @volunteering_activity
  end

  def activity_month_param_key
    :volunteering_activity_month
  end

  def hours_input_path(month_index)
    hours_input_activities_flow_volunteering_path(id: @volunteering_activity, month_index: month_index)
  end

  def activity_display_name
    @volunteering_activity.organization_name
  end

  def hours_input_t_scope
    "activities.community_service.hours_input"
  end

  def hours_input_completed_notice
    t("activities.community_service.created")
  end

  def hours_input_completed_path
    review_activities_flow_volunteering_path(id: @volunteering_activity)
  end

  def review_params
    params.require(:volunteering_activity).permit(:additional_comments)
  end

  def volunteering_activity_params
    params.require(:volunteering_activity).permit(
      :organization_name, :street_address, :street_address_line_2,
      :city, :state, :zip_code,
      :coordinator_name, :coordinator_email, :coordinator_phone_number
    )
  end
end

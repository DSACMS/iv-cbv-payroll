class Activities::VolunteeringController < Activities::BaseController
  before_action :set_volunteering_activity, only: %i[edit update destroy hours_input save_hours]

  include MonthlyHoursInput

  def new
    @volunteering_activity = @flow.volunteering_activities.new
  end

  def create
    @volunteering_activity = @flow.volunteering_activities.new(volunteering_activity_params)
    if @volunteering_activity.save
      destination = redirect_after_save(@volunteering_activity)
      redirect_to destination, notice: (destination == after_activity_path ? t("activities.community_service.created") : nil)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @volunteering_activity.update(volunteering_activity_params)
      destination = redirect_after_save(@volunteering_activity)
      redirect_to destination, notice: (destination == after_activity_path ? t("activities.community_service.updated") : nil)
    else
      render :edit, status: :unprocessable_content
    end
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

  # TODO: Remove — temporary redirect for testing hours_input flow
  def redirect_after_save(activity)
    if params[:redirect_to_hours_input]
      hours_input_activities_flow_volunteering_path(id: activity, month_index: 0)
    else
      after_activity_path
    end
  end

  def volunteering_activity_params
    params.require(:volunteering_activity).permit(:organization_name, :date, :hours)
  end
end

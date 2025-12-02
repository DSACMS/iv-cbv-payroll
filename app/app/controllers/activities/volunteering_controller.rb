class Activities::VolunteeringController < Activities::BaseController
  def new
    @volunteering_activity = @activity_flow.volunteering_activities.new
  end

  def create
    @volunteering_activity = @activity_flow.volunteering_activities.new(volunteering_activity_params)
    if @volunteering_activity.save
      redirect_to activities_flow_root_path, notice: t("activities.volunteering.created")
    else
      render :new
    end
  end

  private

  def volunteering_activity_params
    params.require(:volunteering_activity).permit(:organization_name, :date, :hours)
  end
end

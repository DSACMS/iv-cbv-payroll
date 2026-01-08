class Activities::VolunteeringController < Activities::BaseController
  before_action :set_volunteering_activity, only: %i[edit update destroy]

  def new
    @volunteering_activity = @flow.volunteering_activities.new
  end

  def create
    @volunteering_activity = @flow.volunteering_activities.new(volunteering_activity_params)
    if @volunteering_activity.save
      redirect_to activities_flow_root_path, notice: t("activities.volunteering.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @volunteering_activity.update(volunteering_activity_params)
      redirect_to activities_flow_root_path, notice: t("activities.volunteering.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @volunteering_activity.destroy

    redirect_to activities_flow_root_path, notice: t("activities.volunteering.deleted")
  end

  private

  def set_volunteering_activity
    @volunteering_activity = @flow.volunteering_activities.find(params[:id])
  end

  def volunteering_activity_params
    params.require(:volunteering_activity).permit(:organization_name, :date, :hours)
  end
end

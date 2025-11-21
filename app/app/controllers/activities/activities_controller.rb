class Activities::ActivitiesController < Activities::BaseController
  def show
    @activities = VolunteeringActivity.all
  end
end

class Activities::ActivitiesController < Activities::BaseController
  def show
    @activities = @activity_flow.volunteering_activities.order(created_at: :desc)
  end
end

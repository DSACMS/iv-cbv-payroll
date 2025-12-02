class Activities::ActivitiesController < Activities::BaseController
  def show
    @volunteering_activities = @activity_flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @activity_flow.job_training_activities.order(created_at: :desc)
  end
end

class Activities::SummaryController < Activities::BaseController
  def show
    @volunteering_activities = @flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :desc)
  end
end

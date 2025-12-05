class Activities::ActivitiesController < Activities::BaseController
  def show
    unless @activity_flow.identity
      @activity_flow.identity = IdentityService.new(request).get_identity
      @activity_flow.save
    end

    @volunteering_activities = @activity_flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @activity_flow.job_training_activities.order(created_at: :desc)
    @education_activities = @activity_flow.education_activities.where(confirmed: true).order(created_at: :desc)
  end
end

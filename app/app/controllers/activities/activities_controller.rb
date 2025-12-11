class Activities::ActivitiesController < Activities::BaseController
  def index
    unless @flow.identity
      @flow.identity = IdentityService.new(request).get_identity
      @flow.save
    end


    @volunteering_activities = @flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :desc)
    @education_activities = @flow.education_activities.where(confirmed: true).order(created_at: :desc)
  end
end

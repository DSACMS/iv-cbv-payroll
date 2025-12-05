class Activities::ActivitiesController < Activities::BaseController
  skip_before_action :set_flow, only: [ :entry ]

  def index
    unless @activity_flow.identity
      @activity_flow.identity = IdentityService.new(request).get_identity
      @activity_flow.save
    end


    @volunteering_activities = @flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :desc)
    @education_activities = @activity_flow.education_activities.where(confirmed: true).order(created_at: :desc)
  end

  def entry
    set_generic_flow
  end
end

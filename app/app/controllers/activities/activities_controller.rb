class Activities::ActivitiesController < Activities::BaseController
  skip_before_action :set_flow, only: [ :entry ]

  def index
    unless @flow.identity
      @flow.identity = IdentityService.new(request).get_identity
      @flow.save
    end


    @volunteering_activities = @flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :desc)
    @education_activities = @flow.education_activities.where(confirmed: true).order(created_at: :desc)
  end

  def entry
    set_generic_flow
  end
end

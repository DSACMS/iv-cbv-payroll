class Activities::ActivitiesController < Activities::BaseController
  def index
    unless @flow.identity
      @flow.identity = IdentityService.new(request, @flow.cbv_applicant).get_identity
      @flow.save
    end


    @volunteering_activities = @flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :desc)
    @education_activities_with_terms = @flow.education_activities.joins(:nsc_enrollment_terms).distinct.order(created_at: :desc)
  end
end

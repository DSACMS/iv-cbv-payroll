class Activities::ActivitiesController < Activities::BaseController
  include Cbv::AggregatorDataHelper

  def index
    unless @flow.identity
      @flow.identity = IdentityService.new(request, @flow.cbv_applicant).get_identity
      @flow.save
    end

    @volunteering_activities = @flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :desc)
    @education_activities = @flow.education_activities.includes(:nsc_enrollment_terms).order(created_at: :desc)

    @employment_activities = @flow.payroll_accounts.select(&:sync_succeeded?)
    if @employment_activities.any?
      @cbv_flow = @flow
      set_aggregator_report
    end
  end
end

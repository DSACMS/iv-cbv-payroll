class Activities::ActivitiesController < Activities::BaseController
  def index
    unless @flow.identity
      @flow.identity = IdentityService.new(request, @flow.cbv_applicant).get_identity
      @flow.save
    end

    @community_service_activities = @flow.volunteering_activities.order(created_at: :desc)
    @work_programs_activities = @flow.job_training_activities.order(created_at: :desc)
    @education_activities_with_terms = @flow.education_activities
      .where.associated(:nsc_enrollment_terms)
      .distinct
      .order(created_at: :desc)

    @employment_payroll_accounts = @flow.payroll_accounts.order(created_at: :desc).select(&:sync_succeeded?)
    @persisted_report = PersistedReportAdapter.new(@flow) if @employment_payroll_accounts.any?
  end
end

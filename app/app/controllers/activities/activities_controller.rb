class Activities::ActivitiesController < Activities::BaseController
  def index
    unless @flow.identity
      @flow.identity = IdentityService.new(request, @flow.cbv_applicant).get_identity
      @flow.save
    end

    @community_service_activities = @flow.volunteering_activities.published.order(created_at: :desc)
    @work_programs_activities = @flow.job_training_activities.published.order(created_at: :desc)
    @education_activities = @flow.education_activities.published.order(created_at: :desc)

    @employment_payroll_accounts = @flow.payroll_accounts.published.order(created_at: :desc).select(&:sync_succeeded?)
    @employment_activities = @flow.employment_activities.published.order(created_at: :desc)
    @persisted_report = PersistedReportAdapter.new(@flow) if @employment_payroll_accounts.any?
  end
end

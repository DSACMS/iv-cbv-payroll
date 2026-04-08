class Activities::ActivitiesController < Activities::BaseController
  def index
    unless @flow.identity
      @flow.identity = IdentityService.new(request, @flow.cbv_applicant).get_identity
      @flow.save
    end

    # Hide incomplete activities being tracked in the session so the hub
    # appears clean. The records are deleted later when the user starts a
    # new creation (see track_creating_activity / track_creating_payroll_account).
    excluded_activity_id = creating_activity_id
    excluded_payroll_account_id = creating_payroll_account_aggregator_id

    @community_service_activities = exclude_by_id(@flow.volunteering_activities, "VolunteeringActivity", excluded_activity_id).order(created_at: :desc)
    @work_programs_activities = exclude_by_id(@flow.job_training_activities, "JobTrainingActivity", excluded_activity_id).order(created_at: :desc)
    @education_activities = exclude_by_id(@flow.education_activities, "EducationActivity", excluded_activity_id).order(created_at: :desc)

    @employment_payroll_accounts = @flow.payroll_accounts.where.not(aggregator_account_id: excluded_payroll_account_id).order(created_at: :desc).select(&:sync_succeeded?)
    @employment_activities = exclude_by_id(@flow.employment_activities, "EmploymentActivity", excluded_activity_id).order(created_at: :desc)
    @persisted_report = PersistedReportAdapter.new(@flow) if @employment_payroll_accounts.any?
  end

  private

  def exclude_by_id(scope, class_name, excluded)
    return scope unless excluded&.key?(:id)
    return scope unless excluded[:class_name] == class_name

    scope.where.not(id: excluded[:id])
  end

  def creating_payroll_account_aggregator_id
    creating = session[:creating_payroll_account]
    creating&.dig("aggregator_account_id")
  end
end

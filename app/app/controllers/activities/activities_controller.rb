class Activities::ActivitiesController < Activities::BaseController
  def index
    unless @flow.identity
      @flow.identity = IdentityService.new(request, @flow.cbv_applicant).get_identity
      @flow.save
    end

    # Hide incomplete activities being tracked in the session so the hub
    # appears clean. The records are deleted later when the user starts a
    # new creation (see track_creating_activity / track_creating_payroll_account).
    excluded = creating_records

    @community_service_activities = exclude_from(@flow.volunteering_activities, excluded).order(created_at: :desc)
    @work_programs_activities = exclude_from(@flow.job_training_activities, excluded).order(created_at: :desc)
    @education_activities = exclude_from(@flow.education_activities, excluded).order(created_at: :desc)

    @employment_payroll_accounts = exclude_from(@flow.payroll_accounts, excluded).order(created_at: :desc).select(&:sync_succeeded?)
    @employment_activities = exclude_from(@flow.employment_activities, excluded).order(created_at: :desc)
    @persisted_report = PersistedReportAdapter.new(@flow) if @employment_payroll_accounts.any?

    @any_visible_activities = [ @community_service_activities, @work_programs_activities,
      @education_activities, @employment_payroll_accounts, @employment_activities ].any?(&:any?)
  end

  private

  def exclude_from(scope, records)
    ids = records.select { |r| r.is_a?(scope.klass) }.map(&:id)
    return scope if ids.empty?

    scope.where.not(id: ids)
  end
end

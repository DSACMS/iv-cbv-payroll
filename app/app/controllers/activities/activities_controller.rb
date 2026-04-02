class Activities::ActivitiesController < Activities::BaseController
  def index
    # This is in support of the functionality where we delete any records that were not completed
    # on creation. If you exit out of an activity flow in the middle before you save from the
    # Review page, we should delete all the records that were not completed. This results in no
    # visible changes when the user returns to the Activity Hub.
    if session[:creating_activity]
      activity_class = session[:creating_activity]["class_name"].safe_constantize
      activity_class&.find_by(id: session[:creating_activity]["id"])&.destroy
      session.delete(:creating_activity)
    end

    if session[:creating_payroll_account]
      @flow.payroll_accounts.find_by(aggregator_account_id: session[:creating_payroll_account])&.destroy
      session.delete(:creating_payroll_account)
    end

    unless @flow.identity
      @flow.identity = IdentityService.new(request, @flow.cbv_applicant).get_identity
      @flow.save
    end

    @community_service_activities = @flow.volunteering_activities.order(created_at: :desc)
    @work_programs_activities = @flow.job_training_activities.order(created_at: :desc)
    @education_activities = @flow.education_activities.order(created_at: :desc)

    @employment_payroll_accounts = @flow.payroll_accounts.order(created_at: :desc).select(&:sync_succeeded?)
    @employment_activities = @flow.employment_activities.order(created_at: :desc)
    @persisted_report = PersistedReportAdapter.new(@flow) if @employment_payroll_accounts.any?
  end
end

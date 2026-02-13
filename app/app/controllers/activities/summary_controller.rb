class Activities::SummaryController < Activities::BaseController
  def show
    @community_service_activities = @flow.volunteering_activities.order(created_at: :asc)
    @work_programs_activities = @flow.job_training_activities.order(created_at: :asc)
    @education_activities = @flow.education_activities.order(created_at: :asc)
    @employment_activities = synced_payroll_accounts
    @monthly_summaries_by_account = @flow.monthly_summaries_by_account_with_fallback
    @all_activities = build_activities_list
  end

  private

  def synced_payroll_accounts
    @synced_payroll_accounts ||= @flow.payroll_accounts.select(&:sync_succeeded?)
  end

  def build_activities_list
    activities = []

    @education_activities.each do |activity|
      activities << { type: :education, activity: activity, created_at: activity.created_at }
    end

    @community_service_activities.each do |activity|
      activities << { type: :community_service, activity: activity, created_at: activity.created_at }
    end

    @work_programs_activities.each do |activity|
      activities << { type: :work_programs, activity: activity, created_at: activity.created_at }
    end

    @employment_activities.each do |payroll_account|
      activities << { type: :employment, payroll_account: payroll_account, created_at: payroll_account.created_at }
    end

    activities.sort_by { |activity| activity[:created_at] }
  end
end

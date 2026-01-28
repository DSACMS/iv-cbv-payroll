class Activities::SummaryController < Activities::BaseController
  include Cbv::AggregatorDataHelper

  def show
    load_activities
  end

  private

  def load_activities
    @volunteering_activities = @flow.volunteering_activities.order(created_at: :asc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :asc)
    @education_activities = @flow.education_activities.order(created_at: :asc)
    @synced_payroll_accounts = @flow.payroll_accounts.select(&:sync_succeeded?)
    @all_activities = build_activities_list

    if @synced_payroll_accounts.any?
      @cbv_flow = @flow
      set_aggregator_report
    end
  end

  def build_activities_list
    activities = []

    @education_activities.each do |activity|
      activities << { type: :education, activity: activity, created_at: activity.created_at }
    end

    @volunteering_activities.each do |activity|
      activities << { type: :volunteering, activity: activity, created_at: activity.created_at }
    end

    @job_training_activities.each do |activity|
      activities << { type: :job_training, activity: activity, created_at: activity.created_at }
    end

    @synced_payroll_accounts.each do |payroll_account|
      activities << { type: :income, payroll_account: payroll_account, created_at: payroll_account.created_at }
    end

    activities.sort_by { |activity| activity[:created_at] }
  end
end

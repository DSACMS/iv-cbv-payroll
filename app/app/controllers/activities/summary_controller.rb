class Activities::SummaryController < Activities::BaseController
  include Cbv::AggregatorDataHelper

  before_action :set_flow_for_aggregator
  before_action :set_aggregator_report, if: -> { synced_payroll_accounts.any? }

  def show
    @volunteering_activities = @flow.volunteering_activities.order(created_at: :asc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :asc)
    @education_activities = @flow.education_activities.order(created_at: :asc)
    @employment_activities = synced_payroll_accounts
    @all_activities = build_activities_list
  end

  private

  def set_flow_for_aggregator
    @cbv_flow = @flow
  end

  def synced_payroll_accounts
    @synced_payroll_accounts ||= @flow.payroll_accounts.select(&:sync_succeeded?)
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

    @employment_activities.each do |payroll_account|
      activities << { type: :income, payroll_account: payroll_account, created_at: payroll_account.created_at }
    end

    activities.sort_by { |activity| activity[:created_at] }
  end
end

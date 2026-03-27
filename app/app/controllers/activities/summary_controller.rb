class Activities::SummaryController < Activities::BaseController
  include ConfirmationCodeGeneratable

  before_action :load_summary_data, only: %i[show]

  def show; end

  def update
    unless params.dig(:activity_flow, :consent_to_submit) == "1"
      load_summary_data
      flash.now[:alert] = t("activities.submit.consent_required")
      return render :show, status: :unprocessable_content
    end

    ensure_confirmation_code
    mark_as_completed

    redirect_to activities_flow_success_path
  end

  private

  def ensure_confirmation_code
    return if @flow.complete? || @flow.confirmation_code.present?

    confirmation_code = generate_confirmation_code(@flow)
    @flow.update!(confirmation_code: confirmation_code)
  end

  def mark_as_completed
    @flow.completed_at.nil? ? @flow.update!(completed_at: Time.zone.now) : @flow.touch(:completed_at)
  end

  def load_summary_data
    @community_service_activities = @flow.volunteering_activities.order(created_at: :asc)
    @work_programs_activities = @flow.job_training_activities.order(created_at: :asc)
    @education_activities = @flow.education_activities.order(created_at: :asc)
    @employment_payroll_accounts = @flow.payroll_accounts.select(&:sync_succeeded?)
    @self_attested_employment_activities = @flow.employment_activities.order(created_at: :asc)
    @persisted_report = PersistedReportAdapter.new(@flow)
    @all_activities = build_activities_list
  end

  def build_activities_list
    activities = []

    @education_activities.each do |activity|
      next if activity.validated? && activity.nsc_enrollment_terms.none?
      activities << { type: :education, activity: activity, created_at: activity.created_at }
    end

    @community_service_activities.each do |activity|
      activities << { type: :community_service, activity: activity, created_at: activity.created_at }
    end

    @work_programs_activities.each do |activity|
      activities << { type: :work_programs, activity: activity, created_at: activity.created_at }
    end

    @self_attested_employment_activities.each do |employment_activity|
      activities << { type: :employment, employment_activity: employment_activity, created_at: employment_activity.created_at }
    end

    @employment_payroll_accounts.each do |payroll_account|
      activities << { type: :employment, payroll_account: payroll_account, created_at: payroll_account.created_at }
    end

    activities.sort_by { |activity| activity[:created_at] }
  end
end

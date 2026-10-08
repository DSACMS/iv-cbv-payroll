class Activities::Employment::AddYourWorkController < Activities::BaseController
  ADD_WORK_METHODS = %w[connect_automatically enter_paid_manually enter_unpaid_manually].freeze
  MANUAL_ENTRY_COMPENSATION_TYPES = {
    "enter_paid_manually" => "paid",
    "enter_unpaid_manually" => "unpaid_or_in_kind"
  }.freeze

  after_action :track_viewed_event, only: :show

  def show
  end

  def create
    add_work_method = params[:add_work_method]

    unless ADD_WORK_METHODS.include?(add_work_method)
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      return redirect_to activities_flow_income_add_your_work_path
    end

    track_event(TrackEvent::EmploymentAddYourWorkSubmitted, add_work_method: add_work_method)

    redirect_to next_step_path(add_work_method)
  end

  def add_jobs
    employment_summaries = @flow.employment_summaries_by_account_with_fallback
    @connected_jobs = @flow.payroll_accounts.published.select(&:sync_succeeded?).map do |account|
      employment_summaries.dig(account.aggregator_account_id, :employer_name) ||
        t("activities.employment.title")
    end
    @manual_jobs = @flow.employment_activities.published.pluck(:employer_name)
  end

  def create_add_jobs
    unless params[:additional_jobs].present? && %w[true false].include?(params[:additional_jobs])
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      return redirect_to activities_flow_income_add_jobs_path
    end

    if params[:additional_jobs] == "true"
      redirect_to activities_flow_income_add_your_work_path
    else
      redirect_to after_activity_path
    end
  end

  private

  def next_step_path(add_work_method)
    if add_work_method == "connect_automatically"
      activities_flow_income_employer_search_path
    else
      new_activities_flow_income_employment_path(
        compensation_type: MANUAL_ENTRY_COMPENSATION_TYPES.fetch(add_work_method)
      )
    end
  end

  def track_viewed_event
    return unless response.successful?

    track_event(TrackEvent::EmploymentAddYourWorkViewed)
  end
end

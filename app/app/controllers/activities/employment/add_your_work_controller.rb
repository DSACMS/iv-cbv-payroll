class Activities::Employment::AddYourWorkController < Activities::BaseController
  ADD_WORK_METHODS = %w[connect_automatically enter_paid_manually enter_unpaid_manually].freeze

  after_action :track_page_accessed_event, only: :show

  def show
  end

  def create
    add_work_method = params[:add_work_method]

    unless ADD_WORK_METHODS.include?(add_work_method)
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      return redirect_to activities_flow_income_add_your_work_path
    end

    track_event(TrackEvent::ApplicantContinuedFromAddYourWorkPage, add_work_method: add_work_method)

    redirect_to next_step_path(add_work_method)
  end

  private

  def next_step_path(add_work_method)
    if add_work_method == "connect_automatically"
      activities_flow_income_employer_search_path
    else
      new_activities_flow_income_employment_path
    end
  end

  def track_page_accessed_event
    track_event(TrackEvent::ApplicantAccessedAddYourWorkPage)
  end
end

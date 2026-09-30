class Activities::Education::AddYourEducationController < Activities::BaseController
  ADD_EDUCATION_METHODS = %w[college_or_university high_school_ged trade_or_technical other].freeze

  def show
  end

  def create
    add_education_method = params[:add_education_method]

    unless ADD_EDUCATION_METHODS.include?(add_education_method)
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      return redirect_to activities_flow_education_add_your_education_path
    end

    redirect_to next_step_path(add_education_method)
  end

  private

  def next_step_path(add_education_method)
    case add_education_method
    when "college_or_university"
      nsc_disabled? ? new_activities_flow_education_path : verify_activities_flow_education_index_path
    when "other"
      activities_flow_education_other_path
    else
      new_activities_flow_education_path
    end
  end
end

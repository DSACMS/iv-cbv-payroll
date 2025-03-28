class Cbv::AddJobsController < Cbv::BaseController
  def show
  end

  def create
    destination = next_path()

    if destination == cbv_flow_add_job_path
      flash[:slim_alert] = { message: t("cbv.base.next_add_jobs_path.notice_no_answer"), type: "error" }
    end

    redirect_to destination
  end

  def next_path
    if params[:additional_jobs] == "true"
      cbv_flow_employer_search_path
    elsif params[:additional_jobs] == "false"
      cbv_flow_applicant_information_path
    else
      flash[:slim_alert] = { message: t(".notice_no_answer"), type: "error" }
      cbv_flow_add_job_path
    end
  end
end

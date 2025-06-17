class Cbv::AddJobsController < Cbv::BaseController
  def show
  end

  def create
    redirect_to next_path
  end

  def next_path
    if params[:additional_jobs] == "true"
      cbv_flow_employer_search_path
    elsif params[:additional_jobs] == "false"
      # TODO: FFS-2932 - implement feature flag until language translations are complete
      cbv_flow_other_job_path
    else
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      cbv_flow_add_job_path
    end
  end
end

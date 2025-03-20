class Cbv::AddJobsController < Cbv::BaseController
  def show
  end

  def create
    destination = next_add_jobs_path(params[:additional_jobs])

    if destination == cbv_flow_add_job_path
      flash[:slim_alert] = { message: t(".notice_no_answer"), type: "error" }
    end

    redirect_to destination
  end
end

class Cbv::OtherJobsController < Cbv::BaseController
  def show
  end

  def update
    if other_jobs_params[:has_other_jobs].blank?
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      return redirect_to cbv_flow_other_job_path
    end

    @cbv_flow.update!(other_jobs_params)

    event_logger.track(TrackEvent::ApplicantContinuedFromOtherJobsPage, request, {
      time: Time.now.to_i,
      cbv_flow_id: @cbv_flow&.id,
      client_agency_id: @cbv_flow&.client_agency_id,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      has_other_jobs: @cbv_flow.has_other_jobs
    })
    redirect_to next_path
  end

  private

  def other_jobs_params
    params.fetch(:cbv_flow, {}).permit(:has_other_jobs)
  end
end

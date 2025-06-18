class Cbv::OtherJobsController < Cbv::BaseController
  def show
    # Ensure has_other_jobs is nil so no radio button is pre-selected
    @cbv_flow.has_other_jobs = nil if @cbv_flow.has_other_jobs == false
  end

  def update
    # Check if a value was selected
    if other_jobs_params[:has_other_jobs].blank?
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      return redirect_to cbv_flow_other_job_path
    end

    @cbv_flow.update!(other_jobs_params)

    begin
      event_logger.track("ApplicantContinuedFromOtherJobsPage", request, {
        timestamp: Time.now.to_i,
        cbv_flow_id: @cbv_flow&.id,
        client_agency_id: @cbv_flow&.client_agency_id,
        has_other_jobs: @cbv_flow.has_other_jobs
      })
    rescue => ex
      raise unless Rails.env.production?
      Rails.logger.error "Unable to track ApplicantContinuedFromOtherJobsPage event: #{ex}"
    end
    redirect_to next_path
  end

  private

  def other_jobs_params
    params.fetch(:cbv_flow, {}).permit(:has_other_jobs)
  end
end

class Cbv::OtherJobsController < Cbv::BaseController
  def show
  end

  def create
    @cbv_flow.update!(has_other_jobs: params[:additional_jobs] == "true")

    begin
      event_logger.track("ApplicantContinuedFromOtherJobsPage", request, {
        timestamp: Time.now.to_i,
        referer: request.referer,
        cbv_flow_id: @cbv_flow&.id,
        client_agency_id: @cbv_flow&.client_agency_id,
        has_other_job: @cbv_flow.has_other_jobs
      })
    rescue => ex
      raise unless Rails.env.production?
      Rails.logger.error "Unable to track ApplicantContinuedFromOtherJobsPage event: #{ex}"
    end
    redirect_to next_path
  end

  def next_path
    if params[:additional_jobs] == "true"
      cbv_flow_employer_search_path
    elsif params[:additional_jobs] == "false"
      cbv_flow_applicant_information_path
    else
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      cbv_flow_other_job_path
    end
  end
end

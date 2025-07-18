class Cbv::AddJobsController < Cbv::BaseController
  def show
  end

  def create
    unless params[:additional_jobs].present? && %w[true false].include?(params[:additional_jobs])
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      return redirect_to cbv_flow_add_job_path
    end

    begin
      event_logger.track("ApplicantContinuedFromAddJobsPage", request, {
        timestamp: Time.now.to_i,
        cbv_flow_id: @cbv_flow&.id,
        client_agency_id: @cbv_flow&.client_agency_id,
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        has_additional_jobs: params[:additional_jobs] == "true"
      })
    rescue => ex
      raise unless Rails.env.production?
      Rails.logger.error "Unable to track ApplicantContinuedFromAddJobsPage event: #{ex}"
    end

    redirect_to next_path
  end

  def next_path
    if params[:additional_jobs] == "true"
      cbv_flow_employer_search_path
    elsif params[:additional_jobs] == "false"
      cbv_flow_other_job_path
    end
  end
end

class Cbv::AddJobsController < Cbv::BaseController
  def show
  end

  def create
    begin
      event_logger.track("ApplicantContinuedFromAddJobsPage", request, {
        timestamp: Time.now.to_i,
        cbv_flow_id: @cbv_flow&.id,
        client_agency_id: @cbv_flow&.client_agency_id,
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
      # TODO: FFS-2932 - implement feature flag until language translations are complete
      cbv_flow_other_job_path
    else
      flash[:slim_alert] = { message: t("shared.next_path.notice_no_answer"), type: "error" }
      cbv_flow_add_job_path
    end
  end
end

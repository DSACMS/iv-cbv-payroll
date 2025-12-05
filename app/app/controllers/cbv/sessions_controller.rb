class Cbv::SessionsController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete, :capture_page_view

  def refresh
    session[:last_seen] = Time.current
    head :ok
  end

  def end
    redirect_target = begin
      client_agency_id = CbvFlow.includes(:cbv_applicant).find(session[:flow_id]).cbv_applicant.client_agency_id
      cbv_flow_session_timeout_path(client_agency_id: client_agency_id)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.info "Unable to find CbvFlow in sessions#end. Redirecting to root with timeout"
      root_url(cbv_flow_timeout: true)
    end

    reset_cbv_session!
    redirect_to redirect_target
  end

  def timeout
    reset_cbv_session!
    @current_agency = agency_config[params[:client_agency_id]]
  end

  def current_agency
    @current_agency
  end
end

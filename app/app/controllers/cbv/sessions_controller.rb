class Cbv::SessionsController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete, :capture_page_view

  def refresh
    session[:last_seen] = Time.current
    head :ok
  end

  def end
    client_agency_id = CbvFlow.find(session[:cbv_flow_id]).client_agency_id
    reset_cbv_session!
    redirect_to cbv_flow_session_timeout_path(client_agency_id: client_agency_id)
  end

  def timeout
    reset_cbv_session!
    @current_agency = agency_config[params[:client_agency_id]]
  end

  def current_agency
    @current_agency
  end
end

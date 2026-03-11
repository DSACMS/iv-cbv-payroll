class Cbv::SessionsController < Cbv::BaseController
  skip_before_action :set_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete, :capture_page_view

  def refresh
    session[:last_seen] = Time.current
    head :ok
  end

  def end
    @timeout_path = timeout_path
    reset_cbv_session!
    redirect_to @timeout_path
  end

  def timeout
    reset_cbv_session!
    @current_agency = agency_config[params[:client_agency_id]] || agency_config[client_agency_from_domain]
  end

  private

  def current_agency
    @current_agency
  end

  def timeout_path
    return root_url(cbv_flow_timeout: true) unless session[:flow_type] == :cbv && session[:flow_id].present?

    client_agency_id = CbvFlow.includes(:cbv_applicant).find(session[:flow_id]).cbv_applicant.client_agency_id
    cbv_flow_session_timeout_path(client_agency_id: client_agency_id)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.info "Unable to find CbvFlow in sessions#end. Redirecting to root with timeout"
    root_url(cbv_flow_timeout: true)
  end
end

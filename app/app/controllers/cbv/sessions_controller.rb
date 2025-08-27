class Cbv::SessionsController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete
  skip_after_action :capture_page_view

  def refresh
    session[:last_seen] = Time.current
    head :ok
  end

  def end
    if params[:timeout] == "true"
      track_timeout_event
      flash[:notice] = t("cbv.error_missing_token_html")
    end

    session[:cbv_flow_id] = nil
    redirect_to root_url
  end
end

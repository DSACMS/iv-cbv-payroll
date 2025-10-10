class Cbv::SessionsController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete, :capture_page_view

  def refresh
    session[:last_seen] = Time.current
    head :ok
  end

  def end
    if params[:timeout] == "true"
      flash[:notice] = t("cbv.error_missing_token_html")
    end

    reset_cbv_session!
    redirect_to root_url
  end
end

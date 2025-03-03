class Cbv::ResetsController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :capture_page_view

  def show
    if params[:timeout] == "true"
      track_timeout_event
    end

    session[:cbv_flow_id] = nil
    redirect_to root_url
  end
end

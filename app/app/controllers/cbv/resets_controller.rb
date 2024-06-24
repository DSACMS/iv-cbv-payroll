class Cbv::ResetsController < Cbv::BaseController
  skip_before_action :set_cbv_flow

  def show
    session[:cbv_flow_id] = nil
    redirect_to root_url
  end
end

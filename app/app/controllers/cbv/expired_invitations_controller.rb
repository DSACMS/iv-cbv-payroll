class Cbv::ExpiredInvitationsController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :ensure_cbv_flow_not_yet_complete

  def show
  end
end

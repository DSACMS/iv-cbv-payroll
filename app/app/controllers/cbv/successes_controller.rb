class Cbv::SuccessesController < Cbv::BaseController
  skip_before_action :ensure_cbv_flow_not_yet_complete

  def show
  end
end

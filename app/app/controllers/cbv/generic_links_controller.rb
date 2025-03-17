class Cbv::GenericLinksController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :capture_page_view

  def show
    @cbv_flow = CbvFlow.create_without_invitation(params[:client_agency_id])
    session[:cbv_flow_id] = @cbv_flow.id

    redirect_to next_path
  end
end

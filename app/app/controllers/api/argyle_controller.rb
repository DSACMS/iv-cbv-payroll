class Api::ArgyleController < ApplicationController
  def create
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    argyle = argyle_for(@cbv_flow)
    user = argyle.create_user
    is_sandbox_environment = agency_config[@cbv_flow.client_agency_id].argyle_environment == "sandbox"

    render json: { status: :ok, user: user, isSandbox: is_sandbox_environment }
  end
end

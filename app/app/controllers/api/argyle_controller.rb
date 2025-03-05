class Api::ArgyleController < ApplicationController
  def create
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    argyle = argyle_for(@cbv_flow)
    user = argyle.create_user

    render json: { status: :ok, user: user }
  end
end

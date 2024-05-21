class Api::ArgyleController < ApplicationController
  def update_token
    cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    new_token = refresh_token(cbv_flow.argyle_user_id)

    render json: { status: :ok, token: new_token["user_token"] }
  end

  private

  def refresh_token(argyle_user_id)
    provider.refresh_user_token(argyle_user_id)
  end

  def provider
    ArgyleService.new
  end
end

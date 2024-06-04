class Api::PinwheelController < ApplicationController
  # run the token here with the included employer/payroll provider id
  def fetch_token(type, id)
    cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    new_token = refresh_token(cbv_flow.id)

    render json: { status: :ok, token: new_token["user_token"] }
  end

  private

  def refresh_token(cbv_user_id)
    provider.create_link_token(type, id, cbv_user_id)
  end

  def provider
    PinwheelService.new
  end
end

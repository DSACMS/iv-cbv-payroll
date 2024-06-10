class Api::PinwheelController < ApplicationController
  # run the token here with the included employer/payroll provider id
  def fetch_token
    cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    token = refresh_token(token_params[:response_type], token_params[:id], cbv_flow.id)
    render json: { status: :ok, token: token["data"]["token"] }
  end

  private

  def refresh_token(provider_response_type, provider_id, cbv_user_id)
    provider.create_link_token(response_type: provider_response_type, id: provider_id, end_user_id: cbv_user_id)
  end

  def provider
    PinwheelService.new
  end

  def token_params
    params.require(:pinwheel).permit(:response_type, :id)
  end
end

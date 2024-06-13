class Api::PinwheelController < ApplicationController
  # run the token here with the included employer/payroll provider id
  def create_token
    cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    token_response = provider.create_link_token(
      response_type: token_params[:response_type],
      id: token_params[:id],
      end_user_id: cbv_flow.id
    )
    token = token_response["data"]["token"]

    cbv_flow.update(pinwheel_token_id: token_response["data"]["id"])
    render json: { status: :ok, token: token }
  end

  private

  def provider
    PinwheelService.new
  end

  def token_params
    params.require(:pinwheel).permit(:response_type, :id)
  end
end

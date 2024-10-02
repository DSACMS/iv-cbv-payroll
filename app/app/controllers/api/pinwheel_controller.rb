class Api::PinwheelController < ApplicationController
  after_action :track_event, only: :create_token

  # run the token here with the included employer/payroll provider id
  def create_token
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    pinwheel = pinwheel_for(@cbv_flow)
    puts "the params are #{token_params}"
    token_response = pinwheel.create_link_token(
      response_type: token_params[:response_type],
      id: token_params[:id],
      end_user_id: @cbv_flow.pinwheel_end_user_id,
      language: token_params[:locale]
    )
    token = token_response["data"]["token"]

    render json: { status: :ok, token: token }
  end

  private

  def token_params
    params.require(:pinwheel).permit(:response_type, :id, :locale)
  end

  def track_event
    NewRelicEventTracker.track("ApplicantBeganLinkingEmployer", {
      cbv_flow_id: @cbv_flow.id,
      response_type: token_params[:response_type]
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantBeganLinkingEmployer): #{ex}"
  end
end

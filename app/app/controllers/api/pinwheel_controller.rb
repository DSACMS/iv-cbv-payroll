class Api::PinwheelController < ApplicationController
  after_action :track_event, only: :create_token

  # run the token here with the included employer/payroll provider id
  def create_token
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    pinwheel = pinwheel_for(@cbv_flow)
    token_response = pinwheel.create_link_token(
      response_type: token_params[:response_type],
      id: token_params[:id],
      end_user_id: @cbv_flow.end_user_id,
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
    event_logger.track("ApplicantBeganLinkingEmployer", request, {
      cbv_flow_id: @cbv_flow.id,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      response_type: token_params[:response_type]
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantBeganLinkingEmployer): #{ex}"
  end
end

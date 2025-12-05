class Api::PinwheelController < ApplicationController
  after_action :track_event, only: :create_token

  # run the token here with the included employer/payroll provider id
  def create_token
    @cbv_flow = CbvFlow.find_by(id: session[cbv_flow_symbol])
    return redirect_to(root_url(cbv_flow_timeout: true)) unless @cbv_flow

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
    return unless @cbv_flow.present?

    event_logger.track(TrackEvent::ApplicantBeganLinkingEmployer, request, {
      time: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      client_agency_id: @cbv_flow.cbv_applicant.client_agency_id,
      device_id: @cbv_flow.device_id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      response_type: token_params[:response_type],
      item_id: token_params[:id],
      aggregator_name: "pinwheel"
    })
  end
end

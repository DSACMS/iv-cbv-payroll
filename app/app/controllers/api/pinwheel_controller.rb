class Api::PinwheelController < ApplicationController
  after_action :track_event, only: :create_token

  EVENT_NAMES = %w[
    ApplicantSelectedEmployerOrPlatformItem
    PinwheelAttemptClose
    PinwheelAttemptLogin
    PinwheelCloseModal
    PinwheelError
    PinwheelShowDefaultProviderSearch
    PinwheelShowLoginPage
    PinwheelShowProviderConfirmationPage
    PinwheelSuccess
  ]

  # run the token here with the included employer/payroll provider id
  def create_token
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    pinwheel = pinwheel_for(@cbv_flow)
    token_response = pinwheel.create_link_token(
      response_type: token_params[:response_type],
      id: token_params[:id],
      end_user_id: @cbv_flow.pinwheel_end_user_id,
      language: token_params[:locale]
    )
    token = token_response["data"]["token"]

    render json: { status: :ok, token: token }
  end

  def user_action
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])

    base_attributes = {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    }
    event_name = user_action_params[:event_name]
    event_attributes = user_action_params[:attributes].merge(base_attributes)

    if EVENT_NAMES.include?(event_name)
      NewRelicEventTracker.track(
        event_name,
        event_attributes.to_h
      )
    else
      raise "Unknown Event Type #{event_name.inspect}"
    end

    render json: { status: :ok }
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Unable to process user action: #{ex}"
    render json: { status: :error }, status: :unprocessable_entity
  end

  private

  def user_action_params
    params.fetch(:pinwheel, {}).permit(:event_name, :locale, attributes: {})
  end

  def token_params
    params.require(:pinwheel).permit(:response_type, :id, :locale)
  end

  def track_event
    event_logger.track("ApplicantBeganLinkingEmployer", request, {
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      response_type: token_params[:response_type]
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantBeganLinkingEmployer): #{ex}"
  end
end

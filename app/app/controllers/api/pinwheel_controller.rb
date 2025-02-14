class Api::PinwheelController < ApplicationController
  include CbvEventTracking
  after_action :track_create_token_event, only: :create_token

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

  # Maps Pinwheel event names (keys) to new Mixpanel event names (values) we're using
  MIXPANEL_EVENT_MAP = {
    "PinwheelAccountCreated" => "ApplicantCreatedPinwheelAccount",
    "PinwheelShowProviderConfirmationPage" => "ApplicantViewedPinwheelProviderConfirmation",
    "PinwheelShowLoginPage" => "ApplicantViewedPinwheelLoginPage",
    "PinwheelAttemptLogin" => "ApplicantAttemptedPinwheelLogin",
    "PinwheelSuccess" => "ApplicantSucceededWithPinwheelLogin",
    "PinwheelError" => "ApplicantEncounteredPinwheelError",
    "PinwheelShowDefaultProviderSearch" => "ApplicantViewedPinwheelDefaultProviderSearch",
    "PinwheelAttemptClose" => "ApplicantAttemptedClosingPinwheelModal",
    "PinwheelCloseModal" => "ApplicantClosedPinwheelModal",
    "PinwheelAccountSyncFinished" => "ApplicantFinishedPinwheelSync"
  }

  # run the token here with the included employer/payroll provider id
  def create_token
    pinwheel = pinwheel_for(current_cbv_flow)
    token_response = pinwheel.create_link_token(
      response_type: token_params[:response_type],
      id: token_params[:id],
      end_user_id: current_cbv_flow.pinwheel_end_user_id,
      language: token_params[:locale]
    )

    render json: { status: :ok, token: token_response["data"]["token"] }
  end

  def user_action
    event_name = user_action_params[:event_name]
    # First convert to Hash, then transform keys to symbols
    raw_attrs = user_action_params[:attributes].to_h
    event_attributes = raw_attrs.deep_transform_keys(&:to_sym)

    if EVENT_NAMES.include?(event_name)
      track_event(
        MIXPANEL_EVENT_MAP[event_name] || event_name,
        request,
        event_attributes
      )
      render json: { status: :ok }
    else
      raise "Unknown Event Type #{event_name.inspect}"
    end
  rescue => ex
    raise ex unless Rails.env.production?
    Rails.logger.error "Unable to process user action: #{ex}"
    render json: { status: :error }, status: :unprocessable_entity
  end

  private

  def track_create_token_event
    track_event(
      "ApplicantBeganLinkingEmployer",
      request,
      event_attributes.merge(response_type: token_params[:response_type])
    )
  end

  def user_action_params
    params.fetch(:pinwheel, {}).permit(:event_name, :locale, attributes: {})
  end

  def token_params
    params.require(:pinwheel).permit(:response_type, :id, :locale)
  end
end

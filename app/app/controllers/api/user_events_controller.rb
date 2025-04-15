class Api::UserEventsController < ApplicationController
  EVENT_NAMES = %w[
    ApplicantOpenedHelpModal
    ApplicantSelectedEmployerOrPlatformItem
    PinwheelAttemptClose
    PinwheelAttemptLogin
    PinwheelCloseModal
    PinwheelError
    PinwheelShowDefaultProviderSearch
    PinwheelShowLoginPage
    PinwheelShowProviderConfirmationPage
    PinwheelSuccess
    ArgyleSuccess
    ArgyleAccountCreated
    ArgyleAccountError
    ArgyleAccountRemoved
    ArgyleCloseModal
    ArgyleError
    ArgyleTokenExpired
    ModalAdapterError
    ApplicantViewedArgyleProviderConfirmation
    ApplicantViewedArgyleLoginPage
    ApplicantAttemptedArgyleLogin
    ApplicantViewedArgyleDefaultProviderSearch
    ApplicantAttemptedClosingArgyleModal
    ApplicantAccessedArgyleModalMFAScreen
    ApplicantEncounteredArgyleInvalidCredentialsLoginError
    ApplicantEncounteredArgyleAuthRequiredLoginError
    ApplicantEncounteredArgyleConnectionUnavailableLoginError
    ApplicantEncounteredArgyleExpiredCredentialsLoginError
    ApplicantEncounteredArgyleInvalidAuthLoginError
    ApplicantEncounteredArgyleMfaCanceledLoginError
  ]

  # Maps aggregator event names (keys) to new Mixpanel event names (values) we're using
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
    "PinwheelAccountSyncFinished" => "ApplicantFinishedPinwheelSync",
    "ArgyleSuccess" => "ApplicantSucceededWithArgyleLogin",
    "ArgyleAccountCreated" => "ApplicantCreatedArgyleAccount",
    "ArgyleAccountError" => "ApplicantEncounteredArgyleAccountError",
    "ArgyleAccountRemoved" => "ApplicantRemovedArgyleAccount",
    "ArgyleCloseModal" => "ApplicantClosedArgyleModal",
    "ArgyleError" => "ApplicantEncounteredArgyleError",
    "ArgyleTokenExpired" => "ApplicantEncounteredArgyleTokenExpired",
    "ModalAdapterError" => "ApplicantEncounteredModalAdapterError"
  }

  def user_action
    base_attributes = {
      timestamp: Time.now.to_i
    }

    if session[:cbv_flow_id].present?
      @cbv_flow = CbvFlow.find(session[:cbv_flow_id])

      base_attributes.merge!({
        cbv_flow_id: @cbv_flow.id,
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        client_agency_id: @cbv_flow.client_agency_id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id
      })
    end

    event_attributes = user_action_params[:attributes].merge(base_attributes)
    event_name = user_action_params[:event_name]
    if EVENT_NAMES.include?(event_name)
      # Map to the new Mixpanel event name if present, otherwise just send NewRelic the Pinwheel name
      mixpanel_event_type = MIXPANEL_EVENT_MAP[event_name] || event_name

      event_logger.track(
        mixpanel_event_type,
        request,
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
    params.fetch(:events, {}).permit(:event_name, attributes: {})
  end
end

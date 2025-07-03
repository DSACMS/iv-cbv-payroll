class Api::UserEventsController < ApplicationController
  EVENT_NAMES = %w[
    ApplicantOpenedHelpModal
    ApplicantCopiedInvitationLink
    ApplicantSelectedEmployerOrPlatformItem
    ApplicantAttemptedClosingPinwheelModal
    ApplicantAttemptedPinwheelLogin
    ApplicantClosedPinwheelModal
    ApplicantEncounteredPinwheelError
    ApplicantViewedPinwheelDefaultProviderSearch
    ApplicantViewedPinwheelLoginPage
    ApplicantViewedPinwheelProviderConfirmation
    ApplicantSucceededWithPinwheelLogin
    ApplicantSucceededWithArgyleLogin
    ApplicantCreatedArgyleAccount
    ApplicantEncounteredArgyleAccountError
    ApplicantRemovedArgyleAccount
    ApplicantClosedArgyleModal
    ApplicantEncounteredArgyleError
    ApplicantEncounteredArgyleTokenExpired
    ApplicantEncounteredModalAdapterError
    ApplicantViewedArgyleProviderConfirmation
    ApplicantViewedArgyleLoginPage
    ApplicantAttemptedArgyleLogin
    ApplicantViewedArgyleDefaultProviderSearch
    ApplicantAccessedArgyleModalMFAScreen
    ApplicantEncounteredArgyleInvalidCredentialsLoginError
    ApplicantEncounteredArgyleAuthRequiredLoginError
    ApplicantEncounteredArgyleConnectionUnavailableLoginError
    ApplicantEncounteredArgyleExpiredCredentialsLoginError
    ApplicantEncounteredArgyleInvalidAuthLoginError
    ApplicantEncounteredArgyleMfaCanceledLoginError
    ApplicantUpdatedArgyleSearchTerm
    ApplicantManuallySwitchedLanguage
    ApplicantConsentedToTerms
    ApplicantViewedHelpText
  ]

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

    event_attributes = (user_action_params[:attributes] || {}).merge(base_attributes)
    event_name = user_action_params[:event_name]

    if EVENT_NAMES.include?(event_name)
      event_logger.track(
        event_name,
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

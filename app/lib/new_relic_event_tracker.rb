require_relative "newrelic_event_map.rb"

class NewRelicEventTracker
  # Maps new Mixpanel event names (keys) to old names we used in NewRelic dashboards (values)
  NEWRELIC_EVENT_MAP = {
    "CaseworkerLoggedIn" => "CaseworkerLogin",
    "CaseworkerInvitedApplicantToFlow" => "ApplicantInvitedToFlow",
    "UserManuallySwitchedLanguage" => "LanguageManuallySwitched",
    "ApplicantClickedCBVInvitationLink" => "ClickedCBVInvitationLink",
    "ApplicantViewedPinwheelProviderConfirmation" => "PinwheelShowProviderConfirmationPage",
    "ApplicantViewedPinwheelLoginPage" => "PinwheelShowLoginPage",
    "ApplicantAttemptedPinwheelLogin" => "PinwheelAttemptLogin",
    "ApplicantSucceededWithPinwheelLogin" => "PinwheelSuccess",
    "ApplicantEncounteredPinwheelError" => "PinwheelError",
    "ApplicantViewedPinwheelDefaultProviderSearch" => "PinwheelShowDefaultProviderSearch",
    "ApplicantAttemptedClosingPinwheelModal" => "PinwheelAttemptClose",
    "ApplicantClosedPinwheelModal" => "PinwheelCloseModal",
    "ApplicantFinishedPinwheelSync" => "PinwheelAccountSyncFinished",
    "ApplicantSharedIncomeSummary" => "IncomeSummarySharedWithCaseworker",
    "ApplicantAccessedExpiredLinkPage" => "ApplicantLinkExpired"
  }

  def self.for_request(request)
    new()
  end

  def initialize
  end

  def track(event_type, request, attributes = {})
    start_time = Time.now

    # Map to the old NewRelic event name if present, otherwise just send NewRelic the event_type name
    newrelic_event_type = NEWRELIC_EVENT_MAP[event_type]
    if not newrelic_event_type.present?
      newrelic_event_type = event_type
    end
    Rails.logger.info "  Sending NewRelic event #{newrelic_event_type} with attributes: #{attributes}"

    begin
      response = NewRelic::Agent.record_custom_event(newrelic_event_type, attributes)
      Rails.logger.info "    NewRelic event sent in #{Time.now - start_time}"
    rescue StandardError => e
      raise unless Rails.env.production?

      Rails.logger.error "    Failed to send NewRelic event: #{e.message}"
    end

    response
  end

  # Because we still have calls to this littered around the code
  # TODO can probably delete when I'm done
  def self.track(event_type, request, attributes = {})
  end
end

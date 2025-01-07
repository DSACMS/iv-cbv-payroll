# This map is keyed by Mixpanel event names and will return NewRelic event names
$newrelic_event_map = {
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

import { fetchPinwheelToken, trackUserAction } from "@js/utilities/api.js"
import loadScript from "load-script"
import { getDocumentLocale } from "@js/utilities/getDocumentLocale.js"
import { ModalAdapter } from "./ModalAdapter.js"

export default class PinwheelModalAdapter extends ModalAdapter {
  Pinwheel: Pinwheel

  async open() {
    const locale = getDocumentLocale()

    if (this.requestData) {
      await trackUserAction("ApplicantSelectedEmployerOrPlatformItem", {
        item_type: this.requestData.responseType,
        item_id: this.requestData.id,
        item_name: this.requestData.name,
        is_default_option: this.requestData.isDefaultOption,
        provider_name: this.requestData.providerName,
        locale,
      })

      const { token } = await fetchPinwheelToken(
        this.requestData.responseType,
        this.requestData.id,
        locale
      )

      return Pinwheel.open({
        linkToken: token,
        onSuccess: this.onSuccess.bind(this),
        onExit: this.onExit.bind(this),
        onEvent: this.onEvent.bind(this),
      })
    }
  }

  async onSuccess(eventPayload: LinkResult) {
    await trackUserAction("ApplicantSucceededWithPinwheelLogin", {
      account_id: eventPayload.accountId,
      platform_id: eventPayload.platformId,
    })
    if (this.successCallback) {
      this.successCallback(eventPayload.accountId)
    }
  }

  onEvent(eventName: string, eventPayload: any) {
    switch (eventName) {
      case "screen_transition":
        onScreenTransitionEvent(eventPayload.screenName)
        break
      case "login_attempt":
        trackUserAction("ApplicantAttemptedPinwheelLogin", {})
        break
      case "error":
        const { type, code, message } = eventPayload
        trackUserAction("ApplicantEncounteredPinwheelError", { type, code, message })
        break
      case "exit":
        trackUserAction("ApplicantClosedPinwheelModal", {})
        break
    }

    function onScreenTransitionEvent(screenName: string) {
      switch (screenName) {
        case "LOGIN":
          trackUserAction("ApplicantViewedPinwheelLoginPage", {
            screen_name: screenName,
            employer_name: eventPayload.selectedEmployerName,
            platform_name: eventPayload.selectedPlatformName,
          })
          break
        case "PROVIDER_CONFIRMATION":
          trackUserAction("ApplicantViewedPinwheelProviderConfirmation", {})
          break
        case "SEARCH_DEFAULT":
          trackUserAction("ApplicantViewedPinwheelDefaultProviderSearch", {})
          break
        case "EXIT_CONFIRMATION":
          trackUserAction("ApplicantAttemptedClosingPinwheelModal", {})
          break
      }
    }
  }
}

import { Controller } from "@hotwired/stimulus"
import { loadPinwheel, initializePinwheel, fetchToken, trackUserAction } from "../../utilities/pinwheel"

export default class extends Controller {
  static targets = [
    "form",
    "userAccountId",
    "employerButton"
  ];

  static values = {
    cbvFlowId: Number
  }

  pinwheel = loadPinwheel();

  connect() {
    this.errorHandler = document.addEventListener("turbo:frame-missing", this.onTurboError)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-missing", this.errorHandler)
  }

  onTurboError(event) {
    console.warn("Got turbo error, redirecting:", event)

    const location = event.detail.response.url
    event.detail.visit(location)
    event.preventDefault()
  }

  onPinwheelEvent(eventName, eventPayload) {
    if (eventName === 'success') {
      const { accountId } = eventPayload
      this.userAccountIdTarget.value = accountId
      trackUserAction("PinwheelSuccess", {
        account_id: eventPayload.accountId,
        platform_id: eventPayload.platformId
      })
      this.formTarget.submit();
    } else if (eventName === 'screen_transition') {
      const { screenName } = eventPayload

      switch (screenName) {
        case "LOGIN":
          trackUserAction("PinwheelShowLoginPage", {
            screen_name: screenName,
            employer_name: eventPayload.selectedEmployerName,
            platform_name: eventPayload.selectedPlatformName
          })
          break
        case "PROVIDER_CONFIRMATION":
          trackUserAction("PinwheelShowProviderConfirmationPage", {})
          break
        case "SEARCH_DEFAULT":
          trackUserAction("PinwheelShowDefaultProviderSearch", {})
          break
        case "EXIT_CONFIRMATION":
          trackUserAction("PinwheelAttemptClose", {})
          break
      }
    } else if (eventName === 'login_attempt') {
      trackUserAction("PinwheelAttemptLogin", {})
    } else if (eventName === 'error') {
      const { type, code, message } = eventPayload
      trackUserAction("PinwheelError", { type, code, message })
    } else if (eventName === 'exit') {
      trackUserAction("PinwheelCloseModal", {})
    }
  }

  getDocumentLocale() {
    const docLocale = document.documentElement.lang;
    if (docLocale) return docLocale;
    // Extract locale from URL path (e.g., /en/cbv/employer_search)
    const pathMatch = window.location.pathname.match(/^\/([a-z]{2})\//i);
    return pathMatch ? pathMatch[1] : 'en';
  }

  async select(event) {
    const locale = this.getDocumentLocale();
    const { responseType, id, name, isDefaultOption } = event.target.dataset;
    await trackUserAction("ApplicantSelectedEmployerOrPlatformItem", {
      item_type: responseType,
      item_id: id,
      item_name: name,
      is_default_option: isDefaultOption,
      locale
    })

    this.disableButtons()
    const { token } = await fetchToken(responseType, id, locale);
    this.submit(token);
  }

  submit(token) {
    this.pinwheel.then(Pinwheel => initializePinwheel(Pinwheel, token, {
      onEvent: this.onPinwheelEvent.bind(this),
      onExit: this.reenableButtons.bind(this),
    }));
  }

  disableButtons() {
    this.employerButtonTargets
      .forEach(el => el.setAttribute("disabled", "disabled"))
  }

  reenableButtons() {
    this.employerButtonTargets
      .forEach(el => el.removeAttribute("disabled"))
  }
}

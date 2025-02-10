import { Controller } from "@hotwired/stimulus"
import { loadPinwheel, initializePinwheel } from "../../utilities/pinwheel"
import { fetchToken } from '../../utilities/api';
import { trackUserAction } from '../../utilities/api';
import { getDocumentLocale } from "../../utilities/getDocumentLocale";

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
    this.errorHandler = this.element.addEventListener("turbo:frame-missing", this.onTurboError)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-missing", this.errorHandler)
  }

  onTurboError(event) {
    console.warn("Got turbo error, redirecting:", event)

    const location = event.detail.response.url
    event.detail.visit(location)
    event.preventDefault()
  }

  onSuccessEvent(eventPayload) {

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

  

  async select(event) {
    const locale = getDocumentLocale();
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
      onSuccess: this.onSuccessEvent.bind(this)
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

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

  onPinwheelError(event) {
    const { type, code } = event;
    console.error("Got Pinwheel Error:", type, event);

    if (window.NREUM) {
      window.NREUM.addPageAction("PinwheelError", { type, code, cbvFlowId: this.cbvFlowIdValue })
    }
  }

  onPinwheelEvent(eventName, eventPayload) {
    if (eventName === 'success') {
      const { accountId } = eventPayload;
      this.userAccountIdTarget.value = accountId
      this.formTarget.submit();
    }
  }

  getDocumentLocale() {
    return document.documentElement.lang
  }

  async select(event) {
    const locale = this.getDocumentLocale();

    const { responseType, id, name } = event.target.dataset;
    await trackUserAction(responseType, id, name, locale)

    this.disableButtons()
    const { token } = await fetchToken(responseType, id, locale);
    this.submit(token);
  }

  submit(token) {
    this.pinwheel.then(Pinwheel => initializePinwheel(Pinwheel, token, {
      onEvent: this.onPinwheelEvent.bind(this),
      onError: this.onPinwheelError.bind(this),
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

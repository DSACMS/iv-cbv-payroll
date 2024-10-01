import { Controller } from "@hotwired/stimulus"
import { loadPinwheel, initializePinwheel, fetchToken } from "../../utilities/pinwheel"

export default class extends Controller {
  static targets = [
    "form",
    "userAccountId",
    "employerButton"
  ];

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
    console.error("Got Pinwheel Error:", type, event)

    if (window.NREUM) {
      window.NREUM.addPageAction("PinwheelError", { type, code })
    }
  }

  onPinwheelEvent(eventName, eventPayload) {
    if (eventName === 'success') {
      const { accountId } = eventPayload;
      this.userAccountIdTarget.value = accountId
      this.formTarget.submit();
    }
  }

  async select(event) {
    const { responseType, id } = event.target.dataset;
    this.disableButtons()

    const { token } = await fetchToken(responseType, id);
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

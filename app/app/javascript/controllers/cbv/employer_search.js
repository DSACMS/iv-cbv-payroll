import { Controller } from "@hotwired/stimulus"
import PinwheelProviderWrapper from "../../providers/pinwheel";

export default class extends Controller {
  static targets = [
    "form",
    "userAccountId",
    "employerButton"
  ];

  static values = {
    cbvFlowId: Number
  }

  connect() {
    this.pinwheelWrapper = new PinwheelProviderWrapper({
      onSuccess: this.onSuccess.bind(this),
      onExit: this.reenableButtons.bind(this)
    })
    this.errorHandler = this.element.addEventListener("turbo:frame-missing", this.onTurboError)
  }

  disconnect() {
    this.pinwheelWrapper = null;
    this.element.removeEventListener("turbo:frame-missing", this.errorHandler)
  }

  onTurboError(event) {
    console.warn("Got turbo error, redirecting:", event)

    const location = event.detail.response.url
    event.detail.visit(location)
    event.preventDefault()
  }

  onSuccess(accountId) {
      this.userAccountIdTarget.value = accountId
      this.formTarget.submit();
  }

  async select(event) {

    const locale = getDocumentLocale();
    const { responseType, id, name, isDefaultOption } = event.target.dataset;
    this.disableButtons()
    this.pinwheelWrapper.open(responseType, id, name, isDefaultOption)
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

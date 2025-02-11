import { Controller } from "@hotwired/stimulus"
import PinwheelProviderWrapper, { createProvider, ProviderFactory } from "../../providers/pinwheel";

export default class extends Controller {
  static targets = [
    "form",
    "userAccountId",
    "employerButton"
  ];

  static values = {
    cbvFlowId: Number
  }

  initialize() {
    const ProviderWrapper = createProvider("pinwheel");

    this.providerWrapper = new ProviderWrapper({
      onSuccess: this.onSuccess.bind(this),
      onExit: this.onExit.bind(this)
    })
  }

  connect() {
    this.errorHandler = this.element.addEventListener("turbo:frame-missing", this.onTurboError)
  }

  disconnect() {
    //delete(this.providerWrapper)
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
    const { responseType, id, name, isDefaultOption } = event.target.dataset;
    this.disableButtons()
    await this.providerWrapper.open(responseType, id, name, isDefaultOption)
  }

  disableButtons() {
    this.employerButtonTargets
      .forEach(el => el.setAttribute("disabled", "disabled"))
  }

  onExit() {
    this.showHelpBanner();
    this.employerButtonTargets
      .forEach(el => el.removeAttribute("disabled"))
  }

  showHelpBanner() {
    const url = new URL(window.location.href);
    url.searchParams.set('help', 'true');
    window.location.href = url.toString();
  }
}

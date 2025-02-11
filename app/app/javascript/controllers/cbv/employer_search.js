import { Controller } from "@hotwired/stimulus"
import PinwheelIncomeDataAdapter, { createProvider, ProviderFactory } from "../../providers/pinwheel";

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
    const IncomeDataAdapter = createProvider("pinwheel");

    this.IncomeDataAdapter = new IncomeDataAdapter({
      onSuccess: this.onSuccess.bind(this),
      onExit: this.onExit.bind(this)
    })
  }

  connect() {
    this.errorHandler = this.element.addEventListener("turbo:frame-missing", this.onTurboError)
  }

  disconnect() {
    //delete(this.IncomeDataAdapter)
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
    await this.IncomeDataAdapter.open(responseType, id, name, isDefaultOption)
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

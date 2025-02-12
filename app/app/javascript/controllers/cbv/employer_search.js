import { Controller } from "@hotwired/stimulus"
import { createIncomeDataAdapter } from "../../utilities/createIncomeDataAdapter";

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
    const { responseType, id, name, isDefaultOption, providerName } = this.element.dataset;
    const IncomeDataAdapter = createIncomeDataAdapter(providerName);

    this.IncomeDataAdapter = new IncomeDataAdapter({
      requestData: {
        responseType,
        id,
        isDefaultOption,
        providerName,
        name
      },
      onSuccess: this.onSuccess.bind(this),
      onExit: this.onExit.bind(this)
    })
  }

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

  onSuccess(accountId) {
      this.userAccountIdTarget.value = accountId
      this.formTarget.submit();
  }

  async select(event) {
    this.disableButtons()
    await this.IncomeDataAdapter.open()
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

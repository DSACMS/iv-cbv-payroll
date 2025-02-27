import { Controller } from "@hotwired/stimulus"
import { createModalAdapter } from "../../utilities/createModalAdapter";

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
    const { providerName } = this.element.dataset;
    this.adapter = createModalAdapter(providerName);
  }

  async connect() {
    this.errorHandler = this.element.addEventListener("turbo:frame-missing", this.onTurboError)

  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-missing", this.errorHandler)
    delete(this.ModalAdapter)
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

    const { responseType, id, name, isDefaultOption, providerName } = event.target.dataset;
    this.adapter.init({
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
    await this.adapter.open()
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

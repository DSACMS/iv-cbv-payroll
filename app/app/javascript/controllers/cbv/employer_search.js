import { Controller } from "@hotwired/stimulus"
import { createModalAdapter } from "@js/utilities/createModalAdapter"
import { loadProviderResources } from "@js/utilities/loadProviderResources.ts"

export default class extends Controller {
  static targets = [
    "form",
    "searchButton",
    "userAccountId",
    "employerButton",
    "helpAlert",
    "tabAnnouncement",
  ]

  static values = {
    cbvFlowId: Number,
  }

  async initialize() {
    if (this.hasSearchButtonTarget) {
      this.searchButtonTarget.removeAttribute("disabled")
    }

    await loadProviderResources()
  }

  async connect() {
    this.errorHandler = this.element.addEventListener("turbo:frame-missing", this.onTurboError)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-missing", this.errorHandler)
    delete this.ModalAdapter
  }

  onTurboError(event) {
    console.warn("Got turbo error, redirecting:", event)
    const location = event.detail.response.url
    event.detail.visit(location)
    event.preventDefault()
  }

  onSuccess(accountId) {
    this.userAccountIdTarget.value = accountId
    this.formTarget.submit()
  }

  async select(event) {
    this.disableButtons()
    this.lastFocusedElement = event.currentTarget
    const { responseType, id, name, isDefaultOption, providerName } = event.target.dataset

    this.adapter = createModalAdapter(providerName)
    this.adapter.init({
      requestData: { responseType, id, isDefaultOption, providerName, name },
      onSuccess: this.onSuccess.bind(this),
      onExit: this.onExit.bind(this),
    })

    await this.adapter.open()
  }

  disableButtons() {
    this.employerButtonTargets.forEach((el) => el.setAttribute("disabled", "disabled"))
  }

  onExit() {
    const msToWaitForModalClose = 500
    this.showHelpBanner()
    this.employerButtonTargets.forEach((el) => el.removeAttribute("disabled"))
    setTimeout(() => {
      this.lastFocusedElement.focus()
    }, msToWaitForModalClose)
  }

  showHelpBanner() {
    this.helpAlertTargets.forEach((el) => el.classList.remove("display-none"))
  }

  announceTab(event) {
    const name = event?.currentTarget?.dataset?.tabName ?? event?.target?.dataset?.tabName
    if (!name) return

    this.tabAnnouncementTarget.textContent = name
    try {
      ;(event.currentTarget || event.target).focus()
    } catch (e) {}
  }
}

import { Controller } from "@hotwired/stimulus"
import { createModalAdapter } from "@js/utilities/createModalAdapter"
import { loadProviderResources } from "@js/utilities/loadProviderResources.ts"

export default class extends Controller {
  static targets = [
    "form",
    "userAccountId",
    "employerButton",
    "helpAlert",
    "tabAnnouncement"
  ]

  static values = {
    cbvFlowId: Number,
  }

  async initialize() {
    await loadProviderResources()
    this.pendingAnnouncement = null
    this.pendingTabElement = null
    this._onTurboFrameLoad = this.onTurboFrameLoad.bind(this)
  }

  async connect() {
    this.errorHandler = this.element.addEventListener("turbo:frame-missing", this.onTurboError)
    document.addEventListener("turbo:frame-load", this._onTurboFrameLoad)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-missing", this.errorHandler)
    document.removeEventListener("turbo:frame-load", this._onTurboFrameLoad)
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
    const { responseType, id, name, isDefaultOption, providerName } = event.target.dataset

    this.adapter = createModalAdapter(providerName)
    this.adapter.init({
      requestData: {
        responseType,
        id,
        isDefaultOption,
        providerName,
        name,
      },
      onSuccess: this.onSuccess.bind(this),
      onExit: this.onExit.bind(this),
    })

    await this.adapter.open()
  }

  disableButtons() {
    this.employerButtonTargets.forEach((el) => el.setAttribute("disabled", "disabled"))
  }

  onExit() {
    this.showHelpBanner()
    this.employerButtonTargets.forEach((el) => el.removeAttribute("disabled"))
  }

  showHelpBanner() {
    this.helpAlertTargets.forEach((el) => el.classList.remove("display-none"))
  }

  announceTab(event) {
    const name = event?.currentTarget?.dataset?.tabName || event?.target?.dataset?.tabName
    if (!name) return

    this.pendingAnnouncement = name
    this.pendingTabElement = event.currentTarget || event.target

    this.tabAnnouncementTarget.textContent = `Loading ${name}...`

    try { (event.currentTarget || event.target).focus() } catch (e) {}
  }

  onTurboFrameLoad(event) {
    const frame = event.target
    if (!frame || frame.id !== "popular") return
    const name = this.pendingAnnouncement
    const tabEl = this.pendingTabElement

    if (!name) return

    setTimeout(() => {
      try {
        this.tabAnnouncementTarget.textContent = `${name} providers loaded.`
      } catch (e) {}

      if (tabEl && typeof tabEl.focus === "function") {
        try { tabEl.focus() } catch (e) {}
      }

      this.pendingAnnouncement = null
      this.pendingTabElement = null
    }, 60)
  }
}

import { Controller } from "@hotwired/stimulus"
import { createModalAdapter } from "@js/utilities/createModalAdapter"
import { loadProviderResources } from "@js/utilities/loadProviderResources.ts"
import CSRF from "@js/utilities/csrf"

export default class extends Controller {
  static targets = [
    "form",
    "searchButton",
    "userAccountId",
    "employerButton",
    "helpAlert",
    "tabAnnouncement",
    "consentDialog",
    "consentContinue",
    "consentError",
  ]

  static values = {
    cbvFlowId: Number,
    consentUrl: String,
  }

  async initialize() {
    if (this.hasSearchButtonTarget) {
      this.searchButtonTarget.removeAttribute("disabled")
    }

    await loadProviderResources()
  }

  async connect() {
    this.errorHandler = this.element.addEventListener("turbo:frame-missing", this.onTurboError)
    if (this.hasConsentDialogTarget) {
      this.cancelForTimeout = () => this.cancelConsent()
      document
        .getElementById("open-session-modal-button")
        ?.addEventListener("click", this.cancelForTimeout)
    }
  }

  disconnect() {
    this.pendingSelection = null
    document
      .getElementById("open-session-modal-button")
      ?.removeEventListener("click", this.cancelForTimeout)
    if (this.hasConsentDialogTarget && this.consentDialogTarget.open)
      this.consentDialogTarget.close()
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
    const { responseType, id, name, isDefaultOption, providerName } = event.currentTarget.dataset
    const selection = { responseType, id, name, isDefaultOption, providerName }
    if (this.hasConsentUrlValue) {
      this.pendingSelection = selection
      this.consentErrorTarget.hidden = true
      try {
        const response = await fetch(this.consentUrlValue, {
          headers: { Accept: "application/json" },
          cache: "no-store",
        })
        if (this.pendingSelection !== selection) return
        if (response.redirected) {
          this.redirectTo(response.url)
          return
        }
        if (!response.ok) throw new Error("Consent status unavailable")
        const { consented } = await response.json()
        if (this.pendingSelection !== selection) return
        if (consented !== true) {
          this.consentDialogTarget.showModal()
          return
        }
      } catch {
        if (this.pendingSelection !== selection) return
        this.consentDialogTarget.showModal()
        this.consentErrorTarget.hidden = false
        return
      }
    }
    await this.openProvider(selection)
  }

  async confirmConsent() {
    if (this.consentContinueTarget.disabled) return
    const selection = this.pendingSelection
    if (!selection) return
    this.consentContinueTarget.disabled = true
    this.consentErrorTarget.hidden = true
    try {
      const response = await fetch(this.consentUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": CSRF.token,
        },
        body: JSON.stringify({ consent: "1" }),
      })
      if (this.pendingSelection !== selection) return
      if (response.redirected) {
        this.redirectTo(response.url)
        return
      }
      if (!response.ok || (await response.json()).consented !== true) {
        throw new Error("Consent was not saved")
      }
    } catch {
      if (this.pendingSelection !== selection) return
      this.consentErrorTarget.hidden = false
      this.consentContinueTarget.disabled = false
      return
    }
    if (this.pendingSelection !== selection) return
    this.consentContinueTarget.disabled = false
    this.consentDialogTarget.close()
    await this.openProvider(selection)
  }

  cancelConsent(event) {
    event?.preventDefault()
    this.pendingSelection = null
    this.consentContinueTarget.disabled = false
    this.consentErrorTarget.hidden = true
    if (this.consentDialogTarget.open) this.consentDialogTarget.close()
    this.employerButtonTargets.forEach((el) => el.removeAttribute("disabled"))
    this.lastFocusedElement?.focus()
  }

  redirectTo(url) {
    window.location.href = url
  }

  async openProvider(selection) {
    const { providerName } = selection

    this.adapter = createModalAdapter(providerName)
    this.adapter.init({
      requestData: selection,
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

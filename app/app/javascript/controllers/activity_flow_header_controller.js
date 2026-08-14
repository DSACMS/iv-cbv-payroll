import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "@js/utilities/api.js"

export default class extends Controller {
  static values = { exitUrl: String, confirmOnExit: Boolean, trackEventPrefix: String }
  static targets = [
    "exitButton",
    "modalConfirmButton",
    "modalCancelButton",
    "modalCloseButton",
    "backButton",
  ]

  connect() {
    this.isDirty = false
    this._boundMarkDirty = this._markDirty.bind(this)
    this._formListeners = []
    document.querySelectorAll("form input, form textarea, form select").forEach((el) => {
      el.addEventListener("input", this._boundMarkDirty)
      el.addEventListener("change", this._boundMarkDirty)
      this._formListeners.push(el)
    })

    // Bind tracking handlers directly to their target elements. USWDS moves
    // the modal to <body> on init, which would break Stimulus data-action
    // delegation once the modal is reparented outside the controller root.
    this._trackingBindings = [
      [this._hasTarget("modalConfirmButton") && this.modalConfirmButtonTarget, () => this._trackEvent("ExitModalConfirmed")],
      [this._hasTarget("modalCancelButton") && this.modalCancelButtonTarget, () => this._trackEvent("ExitModalCancelled")],
      [this._hasTarget("modalCloseButton") && this.modalCloseButtonTarget, () => this._trackEvent("ExitModalCancelled")],
      [this._hasTarget("backButton") && this.backButtonTarget, () => this._trackEvent("BackClicked")],
    ]
    this._trackingBindings.forEach(([el, handler]) => {
      if (el) el.addEventListener("click", handler)
    })
  }

  disconnect() {
    this._formListeners.forEach((el) => {
      el.removeEventListener("input", this._boundMarkDirty)
      el.removeEventListener("change", this._boundMarkDirty)
    })
    this._formListeners = []
    ;(this._trackingBindings || []).forEach(([el, handler]) => {
      if (el) el.removeEventListener("click", handler)
    })
    this._trackingBindings = []
  }

  handleExit(event) {
    event.preventDefault()
    const modalShown = this.confirmOnExitValue || this.isDirty
    this._trackEvent("ExitClicked", { modal_shown: modalShown })
    if (modalShown) {
      this.element.querySelector("[data-open-modal]").click()
    } else {
      window.location.href = this.exitUrlValue
    }
  }

  _markDirty() {
    this.isDirty = true
  }

  _hasTarget(name) {
    return this[`has${name.charAt(0).toUpperCase()}${name.slice(1)}Target`]
  }

  _trackEvent(suffix, attributes = {}) {
    if (!this.trackEventPrefixValue) return
    trackUserAction(`${this.trackEventPrefixValue}${suffix}`, attributes)
  }
}

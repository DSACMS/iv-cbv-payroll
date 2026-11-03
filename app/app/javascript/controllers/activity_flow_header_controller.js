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

    // USWDS moves the modal to <body> on init, which happens before this
    // controller connects. That takes the modal's buttons out of this
    // controller's element, so Stimulus targets (scoped to descendants of
    // this.element) can no longer find them - query the reparented modal
    // directly by its id instead.
    const modal = document.getElementById("exit-confirmation-modal")
    const modalButton = (name) =>
      modal?.querySelector(`[data-activity-flow-header-target="${name}"]`)

    this._trackingBindings = [
      [modalButton("modalConfirmButton"), () => this._trackEvent("ExitModalConfirmed")],
      [modalButton("modalCancelButton"), () => this._trackEvent("ExitModalCancelled")],
      [modalButton("modalCloseButton"), () => this._trackEvent("ExitModalCancelled")],
      [
        this._hasTarget("backButton") && this.backButtonTarget,
        () => this._trackEvent("BackClicked"),
      ],
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

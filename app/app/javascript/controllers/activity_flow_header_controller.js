import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { exitUrl: String, backUrl: String, alwaysConfirm: Boolean }

  connect() {
    this.isDirty = false
    this._pendingNavigation = null

    this._boundMarkDirty = this._markDirty.bind(this)
    this._listeners = []
    document.querySelectorAll("form input, form textarea, form select").forEach((el) => {
      el.addEventListener("input", this._boundMarkDirty)
      el.addEventListener("change", this._boundMarkDirty)
      this._listeners.push(el)
    })

    this._boundHandleDocumentClick = this._handleDocumentClick.bind(this)
    document.addEventListener("click", this._boundHandleDocumentClick)
  }

  disconnect() {
    this._listeners.forEach((el) => {
      el.removeEventListener("input", this._boundMarkDirty)
      el.removeEventListener("change", this._boundMarkDirty)
    })
    this._listeners = []

    document.removeEventListener("click", this._boundHandleDocumentClick)
  }

  handleExit(event) {
    event.preventDefault()
    if (this._shouldConfirm()) {
      this._pendingNavigation = () => {
        window.location.href = this.exitUrlValue
      }
      this._openModal()
    } else {
      window.location.href = this.exitUrlValue
    }
  }

  handleBack(event) {
    event.preventDefault()
    window.location.href = this.backUrlValue
  }

  confirmExit() {
    if (this._pendingNavigation) {
      this.isDirty = false
      this._pendingNavigation()
    }
  }

  _shouldConfirm() {
    return this.alwaysConfirmValue || this.isDirty
  }

  _handleDocumentClick(event) {
    if (event.target.closest("[data-action*='activity-flow-header#confirmExit']")) {
      this.confirmExit()
    }
  }

  _openModal() {
    const opener = document.getElementById("open-exit-modal-button")
    if (opener) opener.click()
  }

  _markDirty() {
    this.isDirty = true
  }
}

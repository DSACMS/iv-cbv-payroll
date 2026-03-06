import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { exitUrl: String, backUrl: String, alwaysConfirm: Boolean }

  connect() {
    this.isDirty = false
    this._pendingNavigation = null
    this._blockingNavigation = false
    this._sentinelActive = false

    this._boundMarkDirty = this._markDirty.bind(this)
    this._listeners = []
    document.querySelectorAll("form input, form textarea, form select").forEach((el) => {
      el.addEventListener("input", this._boundMarkDirty)
      el.addEventListener("change", this._boundMarkDirty)
      this._listeners.push(el)
    })

    this._boundHandlePopState = this._handlePopState.bind(this)
    window.addEventListener("popstate", this._boundHandlePopState, true)

    this._boundBeforeUnload = this._handleBeforeUnload.bind(this)
    window.addEventListener("beforeunload", this._boundBeforeUnload)

    this._boundBlockTurboRender = this._blockTurboRender.bind(this)
    document.addEventListener("turbo:before-render", this._boundBlockTurboRender)

    this._boundHandleDocumentClick = this._handleDocumentClick.bind(this)
    document.addEventListener("click", this._boundHandleDocumentClick)

    // Push sentinel history entry so browser back pops the sentinel instead of navigating
    history.pushState({ _activityFlowSentinel: true }, "")
    this._sentinelActive = true
  }

  disconnect() {
    this._listeners.forEach((el) => {
      el.removeEventListener("input", this._boundMarkDirty)
      el.removeEventListener("change", this._boundMarkDirty)
    })
    this._listeners = []

    window.removeEventListener("popstate", this._boundHandlePopState, true)
    window.removeEventListener("beforeunload", this._boundBeforeUnload)
    document.removeEventListener("turbo:before-render", this._boundBlockTurboRender)
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
    if (this._shouldConfirm()) {
      this._pendingNavigation = () => {
        window.location.href = this.backUrlValue
      }
      this._openModal()
    } else {
      window.location.href = this.backUrlValue
    }
  }

  confirmExit() {
    if (this._pendingNavigation) {
      this._blockingNavigation = false
      this._sentinelActive = false
      this.isDirty = false
      this._pendingNavigation()
    }
  }

  _shouldConfirm() {
    return this.alwaysConfirmValue || this.isDirty
  }

  _handlePopState(event) {
    if (this._sentinelActive && !(event.state && event.state._activityFlowSentinel)) {
      // Prevent Turbo Drive from processing this popstate as a restoration visit
      event.stopImmediatePropagation()

      if (this._shouldConfirm()) {
        // Re-push sentinel and show modal
        this._blockingNavigation = true
        history.pushState({ _activityFlowSentinel: true }, "")
        this._pendingNavigation = () => {
          this._blockingNavigation = false
          this._sentinelActive = false
          window.location.href = this.backUrlValue || this.exitUrlValue
        }
        this._openModal()
      } else {
        // No confirmation needed — navigate back directly
        this._sentinelActive = false
        window.Turbo.visit(this.backUrlValue || this.exitUrlValue, { action: "replace" })
      }
    }
  }

  _blockTurboRender(event) {
    if (this._blockingNavigation) {
      event.preventDefault()
    }
  }

  _handleDocumentClick(event) {
    if (event.target.closest("[data-action*='activity-flow-header#confirmExit']")) {
      this.confirmExit()
    } else if (event.target.closest("[data-action*='activity-flow-header#handleBack']")) {
      this.handleBack(event)
    }
  }

  _handleBeforeUnload(event) {
    if (this.isDirty) {
      event.preventDefault()
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

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    if (!this.keyValue) return

    try {
      if (window.sessionStorage.getItem(this.storageKey)) this.element.hidden = true
    } catch {
      // Keep the guidance available when browser storage is disabled.
    }
  }

  dismiss() {
    this.element.hidden = true
    if (!this.keyValue) return

    try {
      window.sessionStorage.setItem(this.storageKey, "true")
    } catch {
      // Dismissal still works on this page when browser storage is disabled.
    }
  }

  get storageKey() {
    return `dismissible-alert:${this.keyValue}`
  }
}

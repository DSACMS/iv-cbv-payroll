import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { exitUrl: String }

  connect() {
    this.isDirty = false
    this._boundMarkDirty = this._markDirty.bind(this)
    document.querySelectorAll("form input, form textarea, form select").forEach((el) => {
      el.addEventListener("input", this._boundMarkDirty)
      el.addEventListener("change", this._boundMarkDirty)
    })
  }

  disconnect() {
    document.querySelectorAll("form input, form textarea, form select").forEach((el) => {
      el.removeEventListener("input", this._boundMarkDirty)
      el.removeEventListener("change", this._boundMarkDirty)
    })
  }

  handleExit(event) {
    event.preventDefault()
    if (this.isDirty) {
      this.element.querySelector("[data-open-modal]").click()
    } else {
      window.location.href = this.exitUrlValue
    }
  }

  _markDirty() {
    this.isDirty = true
  }
}

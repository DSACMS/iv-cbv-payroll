import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthButtons", "monthsInput"]

  connect() {
    const selected = this.element.querySelector("input[name=reporting_window]:checked")
    if (selected) this.applyWindow(selected.value)
  }

  selectWindow(event) {
    this.applyWindow(event.currentTarget.value)
  }

  selectMonths(event) {
    const months = event.currentTarget.dataset.months
    this.monthsInputTarget.value = months
    this.highlightButton(months)
  }

  // private

  applyWindow(value) {
    if (value === "renewal") {
      this.monthButtonsTarget.hidden = true
      this.monthsInputTarget.value = "6"
    } else {
      this.monthButtonsTarget.hidden = false
      this.monthsInputTarget.value = "3"
      this.highlightButton("3")
    }
  }

  highlightButton(activeMonths) {
    this.monthButtonsTarget.querySelectorAll("button").forEach((btn) => {
      if (btn.dataset.months === activeMonths) {
        btn.classList.remove("usa-button--outline")
      } else {
        btn.classList.add("usa-button--outline")
      }
    })
  }
}

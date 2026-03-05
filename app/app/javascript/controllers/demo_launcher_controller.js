import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthButtons", "monthsInput", "ceOnly"]

  connect() {
    const selectedFlow = this.element.querySelector("input[name=flow_type]:checked")
    if (selectedFlow) this.applyFlowType(selectedFlow.value)

    const selectedWindow = this.element.querySelector("input[name=reporting_window]:checked")
    if (selectedWindow) this.applyWindow(selectedWindow.value)
  }

  selectFlowType(event) {
    this.applyFlowType(event.currentTarget.value)
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

  applyFlowType(value) {
    if (value === "cbv") {
      this.ceOnlyTargets.forEach((el) => (el.hidden = true))
    } else {
      this.ceOnlyTargets.forEach((el) => (el.hidden = false))
      const selectedWindow = this.element.querySelector("input[name=reporting_window]:checked")
      if (selectedWindow) this.applyWindow(selectedWindow.value)
    }
  }

  applyWindow(value) {
    if (value === "renewal") {
      this.monthButtonsTarget.classList.add("demo-launcher__month-buttons--hidden")
      this.monthsInputTarget.value = "6"
    } else {
      this.monthButtonsTarget.classList.remove("demo-launcher__month-buttons--hidden")
      this.monthsInputTarget.value = "2"
      this.highlightButton("2")
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

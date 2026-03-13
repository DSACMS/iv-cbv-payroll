import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthButtons", "monthsInput", "ceOnly", "datePickerWrapper"]

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
    this.updateDatePickerFromMonths()
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
    this.updateDatePickerFromMonths()
  }

  updateDatePickerFromMonths() {
    if (!this.hasDatePickerWrapperTarget) return
    const months = parseInt(this.monthsInputTarget.value, 10)
    if (!months) return

    const today = new Date()
    const start = new Date(today.getFullYear(), today.getMonth() - months, 1)
    const yyyy = start.getFullYear()
    const mm = String(start.getMonth() + 1).padStart(2, "0")

    const internalInput = this.datePickerWrapperTarget.querySelector(
      ".usa-date-picker__internal-input"
    )
    const externalInput = this.datePickerWrapperTarget.querySelector(
      ".usa-date-picker__external-input"
    )
    if (internalInput) internalInput.value = `${yyyy}-${mm}-01`
    if (externalInput) externalInput.value = `${mm}/01/${yyyy}`
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

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "monthButtons",
    "monthsInput",
    "ceOnly",
    "datePickerWrapper",
    "genericButton",
    "twoCol",
  ]

  connect() {
    const selectedFlow = this.element.querySelector("input[name=flow_type]:checked")
    if (selectedFlow) this.applyFlowType(selectedFlow.value)

    const selectedWindow = this.element.querySelector("input[name=reporting_window]:checked")
    if (selectedWindow) this.applyWindow(selectedWindow.value)

    const selectedScenario = this.element.querySelector("input[name=test_scenario]:checked")
    if (selectedScenario) this.applyScenario(selectedScenario)
  }

  selectFlowType(event) {
    this.applyFlowType(event.currentTarget.value)
  }

  selectWindow(event) {
    this.applyWindow(event.currentTarget.value)
  }

  selectScenario(event) {
    this.applyScenario(event.currentTarget)
  }

  toggleHint(event) {
    const setting = event.currentTarget.closest(".demo-launcher__setting")
    const hint = setting.querySelector(".demo-launcher__setting-hint")
    if (hint) hint.hidden = !hint.hidden
  }

  toggleInlineHint(event) {
    const hint = event.currentTarget.parentElement.nextElementSibling
    if (hint) hint.hidden = !hint.hidden
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
      if (this.hasTwoColTarget) this.twoColTarget.classList.add("demo-launcher__two-col--single")
      // Deselect any scenario and re-enable Generic
      const noneRadio = this.element.querySelector("#test_scenario_none")
      if (noneRadio) noneRadio.checked = true
      this.updateGenericButton(false)
    } else {
      this.ceOnlyTargets.forEach((el) => (el.hidden = false))
      if (this.hasTwoColTarget) this.twoColTarget.classList.remove("demo-launcher__two-col--single")
      const selectedWindow = this.element.querySelector("input[name=reporting_window]:checked")
      if (selectedWindow) this.applyWindow(selectedWindow.value)
      // Re-apply scenario state
      const selectedScenario = this.element.querySelector("input[name=test_scenario]:checked")
      if (selectedScenario) this.applyScenario(selectedScenario)
    }
  }

  applyScenario(radio) {
    const start = radio.dataset.reportingWindowStart
    const months = radio.dataset.reportingWindowMonths
    const hasScenario = radio.value !== ""

    if (months) {
      this.monthsInputTarget.value = months
      this.highlightButton(months)
    }
    if (start) {
      this.setDatePicker(start)
    } else if (months) {
      this.updateDatePickerFromMonths()
    }

    this.updateGenericButton(hasScenario)
  }

  setDatePicker(dateStr) {
    if (!this.hasDatePickerWrapperTarget) return
    // dateStr is MM/DD/YYYY
    const [mm, dd, yyyy] = dateStr.split("/")
    const internalInput = this.datePickerWrapperTarget.querySelector(
      ".usa-date-picker__internal-input"
    )
    const externalInput = this.datePickerWrapperTarget.querySelector(
      ".usa-date-picker__external-input"
    )
    if (internalInput) internalInput.value = `${yyyy}-${mm}-${dd}`
    if (externalInput) externalInput.value = dateStr
  }

  updateGenericButton(disabled) {
    if (!this.hasGenericButtonTarget) return
    this.genericButtonTarget.disabled = disabled
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

import { Controller } from "@hotwired/stimulus"
import { fetchInternal } from "../utilities/fetchInternal"

export default class extends Controller {
  static targets = [
    "monthButtons",
    "monthsInput",
    "ceOnly",
    "datePickerWrapper",
    "genericButton",
    "renewalRequiredField",
    "tokenizedButton",
    "shareWidget",
    "shareLabel",
    "copyButton",
    "generatedUrl",
    "openGeneratedLink",
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

  invalidateShareLink(event) {
    if (event.target === this.generatedUrlTarget) return

    this.shareWidgetTarget.hidden = true
    this.generatedUrlTarget.value = ""
    this.openGeneratedLinkTarget.href = "#"
    this.resetCopyButton()
  }

  async generateShareLink(event) {
    event.preventDefault()

    const button = event.currentTarget
    const launchType = button.value
    button.disabled = true

    try {
      const formData = new FormData(this.element)
      formData.set("launch_type", launchType)
      const { url } = await fetchInternal(this.element.action, {
        method: this.element.method.toUpperCase(),
        headers: {
          Accept: "application/json",
        },
        body: JSON.stringify(Object.fromEntries(formData.entries())),
        credentials: "same-origin",
      })
      this.generatedUrlTarget.value = url
      this.openGeneratedLinkTarget.href = url
      this.shareLabelTarget.textContent = `${this.humanizeLaunchType(launchType)} link`
      this.shareWidgetTarget.hidden = false
      this.resetCopyButton()
    } catch (_error) {
      this.resetCopyButton()
    } finally {
      button.disabled = false
    }
  }

  async copyGeneratedLink() {
    const url = this.generatedUrlTarget.value
    if (!url) return

    try {
      await navigator.clipboard.writeText(url)
      this.showCopiedState()
    } catch (_error) {
      this.generatedUrlTarget.focus()
      this.generatedUrlTarget.select()
      document.execCommand("copy")
      this.showCopiedState()
    }
  }

  // private

  applyFlowType(value) {
    if (value === "cbv") {
      this.ceOnlyTargets.forEach((el) => (el.hidden = true))
      // Deselect any scenario and re-enable Generic
      const noneRadio = this.element.querySelector("#test_scenario_none")
      if (noneRadio) noneRadio.checked = true
      this.updateGenericButton(false)
    } else {
      this.ceOnlyTargets.forEach((el) => (el.hidden = false))
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
    } else {
      this.clearDatePicker()
    }

    this.updateGenericButton(hasScenario)
  }

  clearDatePicker() {
    if (!this.hasDatePickerWrapperTarget) return
    this.datePickerWrapperTarget.querySelectorAll("input").forEach((input) => (input.value = ""))
  }

  setDatePicker(dateStr) {
    if (!this.hasDatePickerWrapperTarget) return
    // dateStr is MM/DD/YYYY
    const [mm, dd, yyyy] = dateStr.split("/")
    // Set every input in the date picker wrapper — USWDS creates multiple
    // inputs and the form submits whichever one has the name attribute.
    this.datePickerWrapperTarget.querySelectorAll("input").forEach((input) => {
      if (input.type === "text") {
        input.value = dateStr
      } else {
        input.value = `${yyyy}-${mm}-${dd}`
      }
    })
  }

  updateGenericButton(disabled) {
    if (!this.hasGenericButtonTarget) return
    this.genericButtonTarget.disabled = disabled
  }

  humanizeLaunchType(launchType) {
    return launchType === "generic" ? "Generic" : "Tokenized"
  }

  resetCopyButton() {
    if (!this.hasCopyButtonTarget) return

    this.copyButtonTarget.textContent = "Copy link"
    this.copyButtonTarget.classList.add("usa-button--outline")
    this.copyButtonTarget.classList.remove("usa-button--success")
  }

  showCopiedState() {
    if (!this.hasCopyButtonTarget) return

    this.copyButtonTarget.textContent = "Link copied"
    this.copyButtonTarget.classList.remove("usa-button--outline")
    this.copyButtonTarget.classList.add("usa-button--success")
  }

  applyWindow(value) {
    if (value === "renewal") {
      if (this.hasRenewalRequiredFieldTarget) {
        this.renewalRequiredFieldTarget.classList.remove("demo-launcher__renewal-required--hidden")
      }
      this.monthButtonsTarget.classList.add("demo-launcher__month-buttons--hidden")
      this.monthsInputTarget.value = "6"
    } else {
      if (this.hasRenewalRequiredFieldTarget) {
        this.renewalRequiredFieldTarget.classList.add("demo-launcher__renewal-required--hidden")
      }
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

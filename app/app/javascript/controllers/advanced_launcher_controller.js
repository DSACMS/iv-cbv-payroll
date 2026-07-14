import { Controller } from "@hotwired/stimulus"
import { fetchInternal } from "../utilities/fetchInternal"

export default class extends Controller {
  static targets = [
    "monthButtons",
    "monthsInput",
    "ceOnly",
    "activityRow",
    "datePickerWrapper",
    "renewalRequiredField",
    "genericLinkType",
    "copyLaunchButton",
    "openLaunchButton",
    "individualConfiguration",
    "householdConfiguration",
    "householdModeRadio",
    "householdUnavailableHint",
    "householdSelectionHint",
    "incomeFlowRadio",
  ]

  static values = { agencyActivityTypes: Object }

  connect() {
    const selectedLaunchMode = this.element.querySelector("input[name=launch_mode]:checked")
    if (selectedLaunchMode) this.applyLaunchMode(selectedLaunchMode.value)

    const selectedFlow = this.element.querySelector("input[name=flow_type]:checked")
    if (selectedFlow) this.applyFlowType(selectedFlow.value)

    const selectedWindow = this.element.querySelector("input[name=reporting_window]:checked")
    if (selectedWindow) this.applyWindow(selectedWindow.value)

    const selectedScenario = this.element.querySelector("input[name=test_scenario]:checked")
    if (selectedScenario) this.applyScenario(selectedScenario)

    this.applyAgency()
  }

  selectFlowType(event) {
    this.applyFlowType(event.currentTarget.value)
  }

  selectAgency() {
    this.applyAgency()
  }

  selectWindow(event) {
    this.applyWindow(event.currentTarget.value)
  }

  selectScenario(event) {
    this.clearHouseholdArchetypes()
    this.element.querySelector("#launch_mode_individual").checked = true
    this.applyLaunchMode("individual")
    this.applyScenario(event.currentTarget)
  }

  selectLaunchMode(event) {
    const mode = event.currentTarget.value
    if (mode === "household") {
      this.ensureHouseholdArchetypes()
      this.clearIndividualScenarioSelection()
      const activityFlow = this.element.querySelector("#flow_type_activity")
      if (activityFlow) {
        activityFlow.checked = true
        this.applyFlowType(activityFlow.value)
      }
    } else {
      this.clearHouseholdArchetypes()
    }
    this.applyLaunchMode(mode)
  }

  selectHouseholdArchetype() {
    this.clearIndividualScenarioSelection()
    this.element.querySelector("#launch_mode_household").checked = true
    this.applyLaunchMode("household")
  }

  toggleHint(event) {
    const setting = event.currentTarget.closest(".advanced-launcher__setting")
    const hint = setting.querySelector(".advanced-launcher__setting-hint")
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

  toggleActivity(event) {
    const checkbox = event.currentTarget
    const fields = checkbox
      .closest(".advanced-launcher__activity-row")
      .querySelector(".advanced-launcher__activity-fields")
    if (fields) {
      fields.classList.toggle("advanced-launcher__activity-fields--hidden", !checkbox.checked)
    }
  }

  invalidateShareLink() {
    this.resetCopyButton(this.copyLaunchButtonTarget)
  }

  async copyShareLink(event) {
    const button = event.currentTarget
    const url = await this.requestShareLink(button)
    if (!url) return

    try {
      await navigator.clipboard.writeText(url)
      this.showCopiedState(button)
    } catch (_error) {
      this.copyWithSelection(url)
      this.showCopiedState(button)
    }
  }

  openShareLink(event) {
    const newWindow = window.open("", "_blank")
    if (!newWindow) return

    newWindow.opener = null
    this.requestShareLink(event.currentTarget).then((url) => {
      if (url) {
        newWindow.location.href = url
      } else {
        newWindow.close()
      }
    })
  }

  async requestShareLink(button) {
    button.disabled = true

    try {
      const formData = new FormData(this.element)
      formData.set("launch_type", this.selectedLaunchType())
      const payload = Object.fromEntries(formData.entries())
      payload.household_archetypes = formData.getAll("household_archetypes[]")
      const { url } = await fetchInternal(this.element.action, {
        method: this.element.method.toUpperCase(),
        headers: {
          Accept: "application/json",
        },
        body: JSON.stringify(payload),
        credentials: "same-origin",
      })
      return url || null
    } catch (_error) {
      return null
    } finally {
      button.disabled = false
      this.updateHouseholdLaunchControls()
    }
  }

  // private

  selectedLaunchType() {
    if (this.element.querySelector("#launch_mode_household").checked) return "household"

    return this.element.querySelector("input[name=launch_type]:checked").value
  }

  applyFlowType(value) {
    if (value === "cbv") {
      this.ceOnlyTargets.forEach((el) => (el.hidden = true))
      this.clearIndividualScenarios()
      this.updateGenericLinkType(false)
    } else {
      this.ceOnlyTargets.forEach((el) => (el.hidden = false))
      const selectedWindow = this.element.querySelector("input[name=reporting_window]:checked")
      if (selectedWindow) this.applyWindow(selectedWindow.value)
      // Re-apply scenario state
      const selectedScenario = this.element.querySelector("input[name=test_scenario]:checked")
      if (selectedScenario) this.applyScenario(selectedScenario)
    }
  }

  applyAgency() {
    const select = this.element.querySelector("#client_agency_id")
    const enabled = (select && this.agencyActivityTypesValue[select.value]) || []

    this.applyHouseholdAvailability(enabled.length > 0)

    if (!this.hasActivityRowTarget) return

    this.activityRowTargets.forEach((row) => {
      const allowed = enabled.includes(row.dataset.activityType)
      const checkbox = row.querySelector("input[type=checkbox]")

      row.classList.toggle("advanced-launcher__activity-row--disabled", !allowed)
      if (checkbox) checkbox.disabled = !allowed
      if (allowed) return

      if (checkbox && checkbox.checked) {
        checkbox.checked = false
        const fields = row.querySelector(".advanced-launcher__activity-fields")
        if (fields) fields.classList.add("advanced-launcher__activity-fields--hidden")
      }
    })
  }

  applyHouseholdAvailability(supported) {
    this.householdModeRadioTarget.disabled = !supported
    this.householdUnavailableHintTarget.hidden = supported

    if (supported || !this.householdModeRadioTarget.checked) return

    const individual = this.element.querySelector("#launch_mode_individual")
    if (individual) individual.checked = true
    this.clearHouseholdArchetypes()
    this.applyLaunchMode("individual")
  }

  applyLaunchMode(mode) {
    const household = mode === "household"

    this.individualConfigurationTargets.forEach((element) => (element.hidden = household))
    this.householdConfigurationTarget.hidden = !household
    this.incomeFlowRadioTarget.disabled = household
    this.updateGenericLinkType(household)
    this.updateHouseholdLaunchControls()
  }

  updateHouseholdLaunchControls() {
    const household = this.element.querySelector("#launch_mode_household").checked
    const selectedCount = this.element.querySelectorAll(
      "input[name='household_archetypes[]']:checked"
    ).length
    const disabled = household && selectedCount === 0

    this.copyLaunchButtonTarget.disabled = disabled
    this.openLaunchButtonTarget.disabled = disabled
    this.householdSelectionHintTarget.hidden = !disabled
  }

  ensureHouseholdArchetypes() {
    const selectedArchetypes = this.element.querySelectorAll(
      "input[name='household_archetypes[]']:checked"
    )
    if (selectedArchetypes.length > 0) return

    this.element
      .querySelectorAll("input[name='household_archetypes[]']")
      .forEach((input) => (input.checked = input.defaultChecked))
  }

  clearHouseholdArchetypes() {
    this.element
      .querySelectorAll("input[name='household_archetypes[]']")
      .forEach((input) => (input.checked = false))
  }

  clearIndividualScenarios() {
    this.clearIndividualScenarioSelection()
    this.clearDatePicker()
  }

  clearIndividualScenarioSelection() {
    this.element
      .querySelectorAll("input[name=test_scenario]")
      .forEach((input) => (input.checked = false))
    this.updateGenericLinkType(false)
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

    this.updateGenericLinkType(hasScenario)
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

  updateGenericLinkType(disabled) {
    if (!this.hasGenericLinkTypeTarget) return

    this.genericLinkTypeTarget.disabled = disabled
    if (disabled && this.genericLinkTypeTarget.checked) {
      this.element.querySelector("#launch_type_tokenized").checked = true
    }
  }

  copyWithSelection(url) {
    const input = document.createElement("input")
    input.value = url
    document.body.append(input)
    input.select()
    document.execCommand("copy")
    input.remove()
  }

  resetCopyButton(button) {
    button.textContent = "Copy link"
    button.classList.remove("usa-button--success")
  }

  showCopiedState(button) {
    button.textContent = "Link copied"
    button.classList.remove("usa-button--outline")
    button.classList.add("usa-button--success")
  }

  applyWindow(value) {
    if (value === "renewal") {
      if (this.hasRenewalRequiredFieldTarget) {
        this.renewalRequiredFieldTarget.classList.remove(
          "advanced-launcher__renewal-required--hidden"
        )
      }
      this.monthButtonsTarget.classList.add("advanced-launcher__month-buttons--hidden")
      this.monthsInputTarget.value = "6"
    } else {
      if (this.hasRenewalRequiredFieldTarget) {
        this.renewalRequiredFieldTarget.classList.add("advanced-launcher__renewal-required--hidden")
      }
      this.monthButtonsTarget.classList.remove("advanced-launcher__month-buttons--hidden")
      this.monthsInputTarget.value = "2"
      this.highlightButton("2")
    }
  }

  highlightButton(activeMonths) {
    this.monthButtonsTarget.querySelectorAll("button").forEach((button) => {
      button.classList.toggle("usa-button--outline", button.dataset.months !== activeMonths)
    })
  }
}

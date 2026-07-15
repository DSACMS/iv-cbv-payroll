import { describe, beforeEach, afterEach, it, expect } from "vitest"
import AdvancedLauncherController from "@js/controllers/advanced_launcher_controller"

describe("AdvancedLauncherController", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <form
        data-controller="advanced-launcher"
        data-advanced-launcher-agency-activity-types-value='{"sandbox":["employment"],"la_ldh":[]}'
      >
        <select id="client_agency_id" data-action="change->advanced-launcher#selectAgency">
          <option value="sandbox" selected>Sandbox</option>
          <option value="la_ldh">Louisiana</option>
        </select>

        <input
          id="launch_mode_individual"
          type="radio"
          name="launch_mode"
          value="individual"
          checked
          data-action="change->advanced-launcher#selectLaunchMode">
        <input
          id="launch_mode_household"
          type="radio"
          name="launch_mode"
          value="household"
          data-action="change->advanced-launcher#selectLaunchMode"
          data-advanced-launcher-target="householdModeRadio">

        <input id="flow_type_activity" type="radio" name="flow_type" value="activity" checked>
        <input
          id="flow_type_cbv"
          type="radio"
          name="flow_type"
          value="cbv"
          data-advanced-launcher-target="incomeFlowRadio">
        <div data-advanced-launcher-target="activityRow" data-activity-type="employment">
          <input id="employment_enabled" type="checkbox">
        </div>

        <div data-advanced-launcher-target="individualConfiguration">
          <input type="radio" name="test_scenario" value="lynette" checked>
        </div>
        <div data-advanced-launcher-target="householdConfiguration" hidden>
          <input
            id="household_archetype_dominic"
            type="checkbox"
            name="household_archetypes[]"
            value="needs_documentation_one_activity"
            checked
            data-action="advanced-launcher#selectHouseholdArchetype">
          <input
            id="household_archetype_lamine"
            type="checkbox"
            name="household_archetypes[]"
            value="needs_documentation_multiple_activities"
            checked
            data-action="advanced-launcher#selectHouseholdArchetype">
        </div>

        <input id="launch_type_tokenized" type="radio" name="launch_type" value="tokenized">
        <input
          id="launch_type_generic"
          type="radio"
          name="launch_type"
          value="generic"
          checked
          data-advanced-launcher-target="genericLinkType">
        <button type="button" data-advanced-launcher-target="copyLaunchButton"></button>
        <button type="button" data-advanced-launcher-target="openLaunchButton"></button>
        <p hidden data-advanced-launcher-target="householdUnavailableHint"></p>
        <p hidden data-advanced-launcher-target="householdSelectionHint"></p>
      </form>
    `

    window.Stimulus.register("advanced-launcher", AdvancedLauncherController)
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  it("switches between individual and household configurations and updates launch controls", () => {
    document.querySelector("#launch_mode_household").click()

    expect(
      document.querySelector("[data-advanced-launcher-target='individualConfiguration']").hidden
    ).toBe(true)
    expect(
      document.querySelector("[data-advanced-launcher-target='householdConfiguration']").hidden
    ).toBe(false)
    expect(document.querySelector("input[name='test_scenario']").checked).toBe(false)
    expect(document.querySelector("#flow_type_cbv").disabled).toBe(true)
    expect(document.querySelector("#launch_type_generic").disabled).toBe(true)
    expect(document.querySelector("#launch_type_tokenized").checked).toBe(true)

    document.querySelector("#household_archetype_dominic").click()
    document.querySelector("#household_archetype_lamine").click()

    expect(
      document.querySelector("[data-advanced-launcher-target='copyLaunchButton']").disabled
    ).toBe(true)
    expect(
      document.querySelector("[data-advanced-launcher-target='openLaunchButton']").disabled
    ).toBe(true)
    expect(
      document.querySelector("[data-advanced-launcher-target='householdSelectionHint']").hidden
    ).toBe(false)

    document.querySelector("#launch_mode_individual").click()

    expect(
      document.querySelector("[data-advanced-launcher-target='individualConfiguration']").hidden
    ).toBe(false)
    expect(
      document.querySelector("[data-advanced-launcher-target='householdConfiguration']").hidden
    ).toBe(true)
    expect(document.querySelectorAll("input[name='household_archetypes[]']:checked")).toHaveLength(
      0
    )
    expect(document.querySelector("#flow_type_cbv").disabled).toBe(false)
    expect(document.querySelector("#launch_type_generic").disabled).toBe(false)
    expect(
      document.querySelector("[data-advanced-launcher-target='copyLaunchButton']").disabled
    ).toBe(false)
    expect(
      document.querySelector("[data-advanced-launcher-target='openLaunchButton']").disabled
    ).toBe(false)
  })

  it("returns to individual mode when the selected agency does not support household activities", () => {
    document.querySelector("#launch_mode_household").click()

    const agency = document.querySelector("#client_agency_id")
    agency.value = "la_ldh"
    agency.dispatchEvent(new Event("change", { bubbles: true }))

    expect(document.querySelector("#launch_mode_individual").checked).toBe(true)
    expect(document.querySelector("#launch_mode_household").disabled).toBe(true)
    expect(
      document.querySelector("[data-advanced-launcher-target='householdUnavailableHint']").hidden
    ).toBe(false)
    expect(document.querySelectorAll("input[name='household_archetypes[]']:checked")).toHaveLength(
      0
    )
    expect(document.querySelector("#launch_type_tokenized").checked).toBe(true)
    expect(document.querySelector("#employment_enabled").disabled).toBe(true)
  })
})

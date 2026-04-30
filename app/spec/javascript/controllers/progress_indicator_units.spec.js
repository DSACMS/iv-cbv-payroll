import { describe, beforeEach, afterEach, it, expect } from "vitest"
import ProgressIndicatorUnitsController from "@js/controllers/progress_indicator_units_controller"

describe("ProgressIndicatorUnitsController", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <div
        data-controller="progress-indicator-units"
        data-progress-indicator-units-unit-value="hours"
      >
        <button
          type="button"
          data-action="progress-indicator-units#toggle"
          data-progress-indicator-units-target="toggle"
          data-unit="hours"
          data-next-unit="dollars"
        >
          Toggle to dollars
        </button>
        <button
          type="button"
          data-action="progress-indicator-units#toggle"
          data-progress-indicator-units-target="toggle"
          data-unit="dollars"
          data-next-unit="hours"
          hidden
        >
          Toggle to hours
        </button>
        <span data-progress-indicator-units-target="unitContent" data-unit="hours">hours content</span>
        <span data-progress-indicator-units-target="unitContent" data-unit="dollars" hidden>dollars content</span>
      </div>
    `

    window.Stimulus.register("progress-indicator-units", ProgressIndicatorUnitsController)
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  it("keeps keyboard focus on the visible toggle after switching", () => {
    const dollarsToggle = document.querySelector("[data-next-unit='dollars']")
    const hoursToggle = document.querySelector("[data-next-unit='hours']")

    dollarsToggle.focus()
    dollarsToggle.click()

    expect(hoursToggle.hidden).toBe(false)
    expect(document.activeElement).toBe(hoursToggle)
  })

  it("toggles visible content to match the selected unit", () => {
    const dollarsToggle = document.querySelector("[data-next-unit='dollars']")
    const hoursContent = document.querySelector(
      "[data-unit='hours'][data-progress-indicator-units-target='unitContent']"
    )
    const dollarsContent = document.querySelector(
      "[data-unit='dollars'][data-progress-indicator-units-target='unitContent']"
    )

    expect(hoursContent.hidden).toBe(false)
    expect(dollarsContent.hidden).toBe(true)

    dollarsToggle.click()

    expect(hoursContent.hidden).toBe(true)
    expect(dollarsContent.hidden).toBe(false)
  })
})

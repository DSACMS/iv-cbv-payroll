import { describe, beforeEach, it, expect, vi } from "vitest"
import EmploymentPayrollNavigationController from "@js/controllers/employment_payroll_navigation_controller"
import { trackUserAction } from "@js/utilities/api.js"

describe("EmploymentPayrollNavigationController", () => {
  beforeEach(async () => {
    document.body.innerHTML = `
      <div data-controller="employment-payroll-navigation">
        <a data-action="click->employment-payroll-navigation#back">Back to search</a>
      </div>`
    window.Stimulus.register("employment-payroll-navigation", EmploymentPayrollNavigationController)
    await vi.waitFor(() => {
      expect(
        window.Stimulus.getControllerForElementAndIdentifier(
          document.querySelector("div"),
          "employment-payroll-navigation"
        )
      ).not.toBeNull()
    })
  })

  it("tracks the retry back link through the shared helper", () => {
    document.querySelector("a").click()

    expect(trackUserAction).toHaveBeenCalledWith("EmploymentBackClicked", {
      page: "synchronization_failure",
    })
  })
})

import { beforeEach, afterEach, describe, expect, it, vi } from "vitest"
import ErrorSummaryController from "@js/controllers/error_summary_controller"

describe("ErrorSummaryController", () => {
  let frames
  let nextFrameId
  let consoleError
  let originalGlobals

  const mount = async (html) => {
    document.body.innerHTML = html

    document.querySelectorAll("input, select, textarea").forEach((input) => {
      vi.spyOn(input, "getClientRects").mockReturnValue([{}])
    })

    window.Stimulus.register("error-summary", ErrorSummaryController)

    const elements = Array.from(
      document.querySelectorAll('[data-controller~="error-summary"]')
    )

    await vi.waitFor(() => {
      elements.forEach((element) => {
        expect(
          window.Stimulus.getControllerForElementAndIdentifier(
            element,
            "error-summary"
          )
        ).not.toBeNull()
      })
      expect(frames.size).toBe(elements.length)
    })
  }

  const runFrames = () => {
    const callbacks = Array.from(frames.values())
    frames.clear()
    callbacks.forEach((callback) => callback())
  }

  beforeEach(() => {
    originalGlobals = {
      HTMLFormElement: Object.getOwnPropertyDescriptor(globalThis, "HTMLFormElement"),
      requestAnimationFrame: Object.getOwnPropertyDescriptor(globalThis, "requestAnimationFrame"),
      cancelAnimationFrame: Object.getOwnPropertyDescriptor(globalThis, "cancelAnimationFrame"),
    }
    frames = new Map()
    nextFrameId = 0
    consoleError = vi.spyOn(console, "error").mockImplementation(() => { })
    
    Object.defineProperty(globalThis, "HTMLFormElement", {
      configurable: true,
      writable: true,
      value: window.HTMLFormElement,
    })

    Object.defineProperty(globalThis, "requestAnimationFrame", {
      configurable: true,
      writable: true,
      value: vi.fn((callback) => {
        nextFrameId++
        frames.set(nextFrameId, callback)
        return nextFrameId
      }),
    })

    Object.defineProperty(globalThis, "cancelAnimationFrame", {
      configurable: true,
      writable: true,
      value: vi.fn((id) => frames.delete(id)),
    })
  })

  afterEach(() => {
    window.Stimulus.stop()
    document.body.innerHTML = ""
    vi.restoreAllMocks()
    for (const [name, descriptor] of Object.entries(originalGlobals)) {
      if (descriptor) {
        Object.defineProperty(globalThis, name, descriptor)
      } else {
        delete globalThis[name]
      }
    }
  })

  describe("with an associated banner", () => {
    beforeEach(async () => {
      await mount(`
        <div id="summary"
            role="group"
            tabindex="-1"
            data-controller="error-summary"
            data-error-summary-form-id-value="work-form"
            aria-labelledby="summary-heading"
            aria-describedby="summary-body">
          <div id="summary-heading">Check your entries</div>
          <div id="summary-body" data-error-summary-target="body">
            Correct the errors below.
          </div>
        </div>

        <form id="work-form" data-controller="error-summary">
          <label id="income-label" for="income">Gross income</label>
          <span id="income-error"
              class="usa-error-message"
              data-error-label-id="income-label">Enter income</span>
          <input id="income"
              aria-invalid="true"
              aria-describedby="income-error">
            
          <label id="hours-label" for="hours">Hours worked</label>
          <span id="hours-error"
              class="usa-error-message"
              data-error-label-id="hours-label">Enter valid hours</span>
          <input id="hours"
              aria-invalid="true"
              aria-describedby="hours-error">
        </form>

        <form id="other-form">
          <span id="other-error" class="usa-error-message">Unrelated error</span>
        </form>
      `)
    })

    it("describes the banner body followed by each field label and error", () => {
      runFrames()

      expect(
        document.getElementById("summary").getAttribute("aria-describedby")
      ).toBe(
        "summary-body income-label income-error hours-label hours-error"
      )
      expect(consoleError).not.toHaveBeenCalled()
    })

    it("focuses the summary without focusing either invalid input", () => {
      const incomeFocus = vi.spyOn(document.getElementById("income"), "focus")
      const hoursFocus = vi.spyOn(document.getElementById("hours"), "focus")

      runFrames()

      expect(document.activeElement).toBe(document.getElementById("summary"))
      expect(incomeFocus).not.toHaveBeenCalled()
      expect(hoursFocus).not.toHaveBeenCalled()
    })

    it("does not include errors from another form", () => {
      runFrames()

      expect(
        document.getElementById("summary").getAttribute("aria-describedby")
      ).not.toContain("other-error")
    })
  })

  describe("with a banner but no inline errors", () => {
    beforeEach(async () => {
      await mount(`
        <div id="summary"
            tabindex="-1"
            data-controller="error-summary"
            data-error-summary-form-id-value="work-form">
          <div id="summary-body" data-error-summary-target="body">
            Select at least one month.
          </div>
        </div>
        <form id="work-form" data-controller="error-summary"></form>
      `)
    })

    it("focuses the banner and describes only its body", () => {
      runFrames()

      const summary = document.getElementById("summary")
      expect(summary.getAttribute("aria-describedby")).toBe("summary-body")
      expect(document.activeElement).toBe(summary)
      expect(consoleError).not.toHaveBeenCalled()
    })
  })

  describe("without a banner", () => {
    beforeEach(async () => {
      await mount(`
        <form id="work-form" data-controller="error-summary">
          <label for="income">Gross income</label>
          <span id="income-error" class="usa-error-message">Enter income</span>
          <input id="income" aria-invalid="true" aria-describedby="income-hint income-error">

          <span id="hours-error" class="usa-error-message">Enter valid hours</span>
          <input id="hours" aria-describedby="hours-error">
        </form>
      `)
    })

    it("focuses the first field associated with an inline error", () => {
      runFrames()

      expect(document.activeElement).toBe(document.getElementById("income"))
      expect(consoleError).not.toHaveBeenCalled()
    })

    it("skips disabled fields", () => {
      document.getElementById("income").disabled = true

      runFrames()

      expect(document.activeElement).toBe(document.getElementById("hours"))
      expect(consoleError).not.toHaveBeenCalled()
    })

    it("skips fields that are not visible", () => {
      document.getElementById("income").getClientRects.mockReturnValue([])

      runFrames()

      expect(document.activeElement).toBe(document.getElementById("hours"))
      expect(consoleError).not.toHaveBeenCalled()
    })

    it("logs an error when no field references the inline errors", () => {
      document.getElementById("income").removeAttribute("aria-describedby")
      document.getElementById("hours").removeAttribute("aria-describedby")

      runFrames()

      expect(consoleError).toHaveBeenCalledWith(
        "Error summary: no visible, enabled field is associated with the inline errors",
        document.getElementById("work-form")
      )
    })
  })

  describe("with an invalid memorable date and no banner", () => {
    beforeEach(async () => {
      await mount(`
        <form id="applicant-form" data-controller="error-summary">
          <fieldset aria-describedby="applicant_date_of_birth_error">
            <legend id="applicant_date_of_birth_legend">Date of birth</legend>

            <span id="applicant_date_of_birth_error"
                  class="usa-error-message">
                  data-error-label-id="applicant_date_of_birth_legend">
              is invalid
            </span>

            <label for="birth-month">Month</label>
            <select id="birth-month"
                    aria-invalid="true"
                    aria-describedby="applicant_date_of_birth_error">
              <option value="">Select</option>
            </select>

            <label for="birth-day">Day</label>
            <input id="birth-day" type="number"
                   aria-invalid="true"
                   aria-describedby="applicant_date_of_birth_error">

            <label for="birth-year">Year</label>
            <input id="birth-year" type="number"
                   aria-invalid="true"
                   aria-describedby="applicant_date_of_birth_error">
          </fieldset>
        </form>  
      `)
    })

    it("focuses the month select without logging an association error", () => {
      runFrames()

      expect(document.activeElement).toBe(document.getElementById("birth-month"))
      expect(consoleError).not.toHaveBeenCalled()
    })

    it("focuses the day input when the month select is disabled", () => {
      document.getElementById("birth-month").disabled = true

      runFrames()

      expect(document.activeElement).toBe(document.getElementById("birth-day"))
      expect(consoleError).not.toHaveBeenCalled()
    })
  })

  describe("with no errors", () => {
    beforeEach(async () => {
      await mount(`
        <button id="existing-focus">Existing focus</button>
        <form data-controller="error-summary">
          <input id="income">
        </form>
      `)
    })

    it("leaves focus unchanged", () => {
      const button = document.getElementById("existing-focus")
      button.focus()

      runFrames()

      expect(document.activeElement).toBe(button)
      expect(consoleError).not.toHaveBeenCalled()
    })
  })

  describe("when disconnected before the scheduled focus", () => {
    beforeEach(async () => {
      await mount('<form data-controller="error-summary"></form>')
    })

    it("cancels the pending animation frame", () => {
      const form = document.querySelector("form")
      const controller =
        window.Stimulus.getControllerForElementAndIdentifier(form, "error-summary")
      
      controller.disconnect()

      expect(cancelAnimationFrame).toHaveBeenCalled(controller.frameId)
      expect(frames.size).toBe(0)
    })
  })
})

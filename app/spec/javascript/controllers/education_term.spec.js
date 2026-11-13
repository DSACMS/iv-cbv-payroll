import { describe, beforeEach, afterEach, it, expect } from "vitest"
import EducationTermController from "@js/controllers/education_term_controller"
import HoursInputController from "@js/controllers/hours_input_controller"

describe("EducationTermController", () => {
  let enrollmentStatus
  let creditHours
  let creditHoursField

  beforeEach(() => {
    document.body.innerHTML = `
      <form data-controller="education-term"
            data-education-term-credit-hours-statuses-value='["less_than_half_time", "unknown"]'>
        <select data-education-term-target="enrollmentStatus"
                data-action="change->education-term#enrollmentStatusChanged">
          <option value="">Select one</option>
          <option value="full_time">Full-time</option>
          <option value="half_time">Half-time</option>
          <option value="less_than_half_time">Less than half-time</option>
          <option value="unknown">I'm not sure</option>
        </select>
        <div data-education-term-target="creditHours">
          <input data-education-term-target="creditHoursField" value="3.5">
        </div>
      </form>
    `

    enrollmentStatus = document.querySelector("select")
    creditHours = document.querySelector('[data-education-term-target="creditHours"]')
    creditHoursField = document.querySelector("input")
    window.Stimulus.register("education-term", EducationTermController)
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  function selectEnrollmentStatus(value) {
    enrollmentStatus.value = value
    enrollmentStatus.dispatchEvent(new window.Event("change", { bubbles: true }))
  }

  it("hides and disables credit hours until an applicable status is selected", () => {
    expect(creditHours.hidden).toBe(true)
    expect(creditHoursField.disabled).toBe(true)
  })

  it("shows credit hours for less than half-time enrollment", () => {
    selectEnrollmentStatus("less_than_half_time")

    expect(creditHours.hidden).toBe(false)
    expect(creditHoursField.disabled).toBe(false)
  })

  it("shows credit hours when the enrollment status is unknown", () => {
    selectEnrollmentStatus("unknown")

    expect(creditHours.hidden).toBe(false)
    expect(creditHoursField.disabled).toBe(false)
  })

  it("disables credit hours when switching to full-time enrollment", () => {
    selectEnrollmentStatus("less_than_half_time")
    selectEnrollmentStatus("full_time")

    expect(creditHours.hidden).toBe(true)
    expect(creditHoursField.disabled).toBe(true)
  })

  it("disables credit hours when switching to half-time enrollment", () => {
    selectEnrollmentStatus("unknown")
    selectEnrollmentStatus("half_time")

    expect(creditHours.hidden).toBe(true)
    expect(creditHoursField.disabled).toBe(true)
  })

  it("preserves credit hours when switching back to a status that uses them", () => {
    selectEnrollmentStatus("less_than_half_time")
    selectEnrollmentStatus("full_time")
    selectEnrollmentStatus("unknown")

    expect(creditHoursField.value).toBe("3.5")
    expect(creditHoursField.disabled).toBe(false)
  })

  describe("with a no-classes checkbox", () => {
    let noHoursCheckbox

    beforeEach(() => {
      const form = document.querySelector("form")
      form.dataset.controller = "education-term hours-input"
      form.insertAdjacentHTML(
        "afterbegin",
        `<input type="checkbox"
                data-education-term-target="noHoursCheckbox"
                data-hours-input-target="checkbox"
                data-action="change->hours-input#toggle change->education-term#noHoursChanged">`
      )
      creditHoursField.dataset.hoursInputTarget = "hoursField"
      noHoursCheckbox = document.querySelector('input[type="checkbox"]')
      window.Stimulus.register("hours-input", HoursInputController)
    })

    function toggleNoHours(checked) {
      noHoursCheckbox.checked = checked
      noHoursCheckbox.dispatchEvent(new window.Event("change", { bubbles: true }))
    }

    it("clears the selected enrollment status when no classes were taken", () => {
      selectEnrollmentStatus("half_time")
      toggleNoHours(true)

      expect(enrollmentStatus.value).toBe("")
      expect(noHoursCheckbox.checked).toBe(true)
      expect(creditHoursField.value).toBe("0")
      expect(creditHours.hidden).toBe(true)
    })

    it("clears the checkbox's zero hours when selecting less than half-time", () => {
      toggleNoHours(true)
      selectEnrollmentStatus("less_than_half_time")

      expect(noHoursCheckbox.checked).toBe(false)
      expect(creditHoursField.value).toBe("")
      expect(creditHoursField.disabled).toBe(false)
    })

    it("clears the checkbox's zero hours when the applicant is unsure", () => {
      toggleNoHours(true)
      selectEnrollmentStatus("unknown")

      expect(noHoursCheckbox.checked).toBe(false)
      expect(creditHoursField.value).toBe("")
      expect(creditHoursField.disabled).toBe(false)
    })

    it("clears the checkbox's zero hours when unchecking no classes", () => {
      toggleNoHours(true)
      toggleNoHours(false)

      expect(noHoursCheckbox.checked).toBe(false)
      expect(creditHoursField.value).toBe("")
    })
  })
})

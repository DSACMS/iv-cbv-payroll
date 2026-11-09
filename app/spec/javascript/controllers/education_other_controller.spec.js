import { describe, beforeEach, afterEach, it, expect } from "vitest"
import EducationOtherController from "@js/controllers/education_other_controller"
import { trackUserAction } from "@js/utilities/api.js"

describe("EducationOtherController", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <a href="#not-listed" data-controller="education-other"
         data-action="click->education-other#trackLink"
         data-education-other-link-param="not_listed">Education not listed</a>
      <a href="#job-training" data-controller="education-other"
         data-action="click->education-other#trackLink"
         data-education-other-link-param="job_training">Job training</a>
      <a href="#internship" data-controller="education-other"
         data-action="click->education-other#trackLink"
         data-education-other-link-param="internship">Internship</a>
      <a href="#home" data-controller="education-other"
         data-action="click->education-other#trackLink"
         data-education-other-link-param="exit_to_home">Return home</a>
    `

    window.Stimulus.register("education-other", EducationOtherController)
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  it.each(["not_listed", "job_training", "internship", "exit_to_home"])(
    "tracks %s once without preventing navigation",
    (link) => {
      const anchor = document.querySelector(`[data-education-other-link-param="${link}"]`)
      const event = new window.MouseEvent("click", { bubbles: true, cancelable: true })

      anchor.dispatchEvent(event)

      expect(trackUserAction).toHaveBeenCalledExactlyOnceWith("EducationOtherLinkClicked", { link })
      expect(event.defaultPrevented).toBe(false)
    }
  )
})

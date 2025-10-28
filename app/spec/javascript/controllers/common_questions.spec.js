import { describe, beforeEach, afterEach, it, expect } from "vitest"
import CommonQuestionsController from "@js/controllers/common_questions_controller"
import { trackUserAction } from "@js/utilities/api"

describe("CommonQuestionsController", () => {
  let button

  beforeEach(() => {
    button = document.createElement("button")
    button.setAttribute("data-controller", "common-questions")
    button.setAttribute("data-action", "click->common-questions#view")
    button.setAttribute("data-section-identifier", "what_if_i_lost_my_job")
    button.setAttribute("data-page", "employer_search")
    button.setAttribute("aria-expanded", "false")
    document.body.appendChild(button)

    window.Stimulus.register("common-questions", CommonQuestionsController)
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  it("tracks when expanding an accordion", async () => {
    await button.click()
    expect(trackUserAction).toBeCalledTimes(1)
    expect(trackUserAction).toHaveBeenCalledWith("ApplicantViewedHelpText", {
      page: "employer_search",
      section: "what_if_i_lost_my_job",
    })
  })

  it("does not track when already expanded", async () => {
    button.setAttribute("aria-expanded", "true")
    await button.click()
    expect(trackUserAction).not.toBeCalled()
  })
})

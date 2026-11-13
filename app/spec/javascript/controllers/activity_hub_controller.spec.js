import { describe, beforeEach, it, expect } from "vitest"
import ActivityHubController from "@js/controllers/activity_hub_controller"
import { trackUserAction } from "@js/utilities/api.js"

describe("ActivityHubController", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <main
        data-controller="activity-hub"
        data-action="click->activity-hub#trackClick"
      >
        <section data-activity-type="education">
          <form data-hub-action="add">
            <button type="button">Add</button>
          </form>
          <a href="#edit" data-hub-action="edit">Edit</a>
        </section>
        <form data-hub-action="review">
          <button type="button">Review and submit</button>
        </form>
        <button type="button">Untracked</button>
      </main>
    `

    window.Stimulus.register("activity-hub", ActivityHubController)
  })

  it("tracks adding an activity with its type", () => {
    document.querySelector("[data-hub-action='add'] button").click()

    expect(trackUserAction).toHaveBeenCalledWith("HubSpokeSelected", {
      activity_type: "education",
      action: "add",
    })
  })

  it("tracks editing an activity with its type", () => {
    document.querySelector("[data-hub-action='edit']").click()

    expect(trackUserAction).toHaveBeenCalledWith("HubSpokeSelected", {
      activity_type: "education",
      action: "edit",
    })
  })

  it("tracks review and submit clicks", () => {
    document.querySelector("[data-hub-action='review'] button").click()

    expect(trackUserAction).toHaveBeenCalledWith("HubReviewAndSubmitClicked")
  })

  it("does not track unrelated clicks", () => {
    document.querySelector("main > button").click()

    expect(trackUserAction).not.toHaveBeenCalled()
  })
})

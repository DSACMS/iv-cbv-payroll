import { describe, beforeEach, it, expect } from "vitest"
import ActivityFlowHeaderController from "@js/controllers/activity_flow_header_controller"
import { trackUserAction } from "@js/utilities/api.js"

describe("ActivityFlowHeaderController", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="activity-flow-header"
           data-activity-flow-header-exit-url-value="/exit"
           data-activity-flow-header-confirm-on-exit-value="true"
           data-activity-flow-header-track-event-prefix-value="Employment">
        <a data-action="click->activity-flow-header#handleExit"
           data-activity-flow-header-target="exitButton">Exit</a>
        <a data-activity-flow-header-target="backButton">Back</a>
        <button data-open-modal id="open-exit-modal-button"></button>
      </div>
    `

    // USWDS moves .usa-modal to <body> before Stimulus connects (see the
    // comment in activity_flow_header_controller.js) - append it as a
    // sibling of the controller element, not a descendant, to reproduce
    // that real-world ordering.
    const modal = document.createElement("div")
    modal.id = "exit-confirmation-modal"
    modal.innerHTML = `
      <button data-activity-flow-header-target="modalCancelButton">Back</button>
      <button data-activity-flow-header-target="modalCloseButton">Close</button>
      <a data-activity-flow-header-target="modalConfirmButton">Exit without saving</a>
    `
    document.body.appendChild(modal)

    window.Stimulus.register("activity-flow-header", ActivityFlowHeaderController)
  })

  it("tracks ExitModalCancelled when the modal's back (cancel) button is clicked", () => {
    document.querySelector('[data-activity-flow-header-target="modalCancelButton"]').click()

    expect(trackUserAction).toHaveBeenCalledWith("EmploymentExitModalCancelled", {})
  })

  it("tracks ExitModalCancelled when the modal's X (close) button is clicked", () => {
    document.querySelector('[data-activity-flow-header-target="modalCloseButton"]').click()

    expect(trackUserAction).toHaveBeenCalledWith("EmploymentExitModalCancelled", {})
  })

  it("tracks ExitModalConfirmed when the modal's exit link is clicked", () => {
    document.querySelector('[data-activity-flow-header-target="modalConfirmButton"]').click()

    expect(trackUserAction).toHaveBeenCalledWith("EmploymentExitModalConfirmed", {})
  })

  describe("NSC education context", () => {
    const attributes = {
      education_activity_id: 123,
      education_flow: "nsc",
      education_data_source: "partially_self_attested",
      education_step: "enrollment_review",
    }

    beforeEach(() => {
      const header = document.querySelector('[data-controller="activity-flow-header"]')
      header.dataset.activityFlowHeaderTrackEventPrefixValue = "Education"
      header.dataset.activityFlowHeaderTrackEventAttributesValue = JSON.stringify(attributes)
    })

    it("tracks the exit click and whether the modal is shown", () => {
      document.querySelector('[data-activity-flow-header-target="exitButton"]').click()

      expect(trackUserAction).toHaveBeenCalledWith("EducationExitClicked", {
        ...attributes,
        modal_shown: true,
      })
    })

    it("tracks back clicks with the partial journey context", () => {
      document.querySelector('[data-activity-flow-header-target="backButton"]').click()

      expect(trackUserAction).toHaveBeenCalledWith("EducationBackClicked", attributes)
    })

    it("tracks cancelling the exit warning with the partial journey context", () => {
      document.querySelector('[data-activity-flow-header-target="modalCancelButton"]').click()

      expect(trackUserAction).toHaveBeenCalledWith("EducationExitModalCancelled", attributes)
    })

    it("tracks confirming exit with the partial journey context", () => {
      document.querySelector('[data-activity-flow-header-target="modalConfirmButton"]').click()

      expect(trackUserAction).toHaveBeenCalledWith("EducationExitModalConfirmed", attributes)
    })
  })
})

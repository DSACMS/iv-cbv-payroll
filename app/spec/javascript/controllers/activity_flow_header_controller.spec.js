import { describe, beforeEach, it, expect } from "vitest"
import ActivityFlowHeaderController from "@js/controllers/activity_flow_header_controller"
import { trackUserAction } from "@js/utilities/api.js"

describe.each(["Employment", "Education", "WorkProgram"])(
  "ActivityFlowHeaderController %s",
  (prefix) => {
    beforeEach(() => {
      document.body.innerHTML = `
      <div data-controller="activity-flow-header"
           data-activity-flow-header-exit-url-value="/exit"
           data-activity-flow-header-confirm-on-exit-value="true"
           data-activity-flow-header-track-event-prefix-value="${prefix}">
        <a data-action="click->activity-flow-header#handleExit"
           data-activity-flow-header-target="exitButton">Exit</a>
        <button data-activity-flow-header-target="backButton">Back</button>
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

      expect(trackUserAction).toHaveBeenCalledWith(`${prefix}ExitModalCancelled`, {})
    })

    it("tracks ExitModalCancelled when the modal's X (close) button is clicked", () => {
      document.querySelector('[data-activity-flow-header-target="modalCloseButton"]').click()

      expect(trackUserAction).toHaveBeenCalledWith(`${prefix}ExitModalCancelled`, {})
    })

    it("tracks ExitModalConfirmed when the modal's exit link is clicked", () => {
      document.querySelector('[data-activity-flow-header-target="modalConfirmButton"]').click()

      expect(trackUserAction).toHaveBeenCalledWith(`${prefix}ExitModalConfirmed`, {})
    })
    it("tracks back clicks", () => {
      document.querySelector('[data-activity-flow-header-target="backButton"]').click()

      expect(trackUserAction).toHaveBeenCalledWith(`${prefix}BackClicked`, {})
    })

    it("tracks exit clicks with the modal decision", () => {
      document.querySelector('[data-activity-flow-header-target="exitButton"]').click()

      expect(trackUserAction).toHaveBeenCalledWith(`${prefix}ExitClicked`, { modal_shown: true })
    })
  }
)

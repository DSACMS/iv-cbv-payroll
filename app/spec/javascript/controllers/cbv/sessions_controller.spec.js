import { vi, describe, beforeEach, afterEach, it, expect } from "vitest"
import { Application } from "@hotwired/stimulus"
import SessionController from "@js/controllers/cbv/sessions_controller.js"

vi.mock("@js/utilities/api", () => ({
  trackUserAction: vi.fn(),
}))
import { trackUserAction } from "@js/utilities/api"

function setupDOM(timeoutSeconds = 600) {
  document.body.innerHTML = `
    <div id="session-timeout-modal" data-controller="session" data-session-target="modal" data-item-timeout-param="${timeoutSeconds}">
      <form id="extend-session-form"><button id="extend-session-button" data-close-modal="true" type="submit" data-action="session#trackExtend"></button></form>
    </div>
    <button id="open-session-modal-button"></button>
  `
}

describe("cbv/sessions_controller", () => {
  let application

  beforeEach(() => {
    setupDOM(600)
    application = Application.start()
    application.register("session", SessionController)
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
    application?.stop()
    document.body.innerHTML = ""
    vi.resetAllMocks()
  })

  it("tracks ApplicantWarnedAboutTimeout when warning timer fires", async () => {
    vi.advanceTimersByTime(300 * 1000)
    expect(trackUserAction).toHaveBeenCalledWith("ApplicantWarnedAboutTimeout")
  })

  it("tracks ApplicantTimedOut before redirect when expiration timer fires", async () => {
    try {
      vi.advanceTimersByTime(600 * 1000)
    } catch (_) {}
    expect(trackUserAction).toHaveBeenCalledWith("ApplicantTimedOut")
  })

  it("tracks ApplicantExtendedSession on extend button click", async () => {
    const extendButton = document.getElementById("extend-session-button")
    extendButton.click()
    expect(trackUserAction).toHaveBeenCalledWith("ApplicantExtendedSession")
  })

  it("tracks ApplicantEndedSession on extend button click", async () => {
    const endButton = document.getElementById("end-session-button")
    extendButton.click()
    expect(trackUserAction).toHaveBeenCalledWith("ApplicantEndedSession")
  })
})

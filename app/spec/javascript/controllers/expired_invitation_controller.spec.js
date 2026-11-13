import { describe, beforeEach, it, expect } from "vitest"
import ExpiredInvitationController from "@js/controllers/expired_invitation_controller"
import { trackUserAction } from "@js/utilities/api.js"

describe("ExpiredInvitationController", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <a href="https://agency.example"
         data-controller="expired-invitation"
         data-action="click->expired-invitation#trackAgencyWebsiteClick">
        Visit agency website
      </a>
    `

    window.Stimulus.register("expired-invitation", ExpiredInvitationController)
  })

  it("tracks clicks on the agency website link", () => {
    document.querySelector("a").click()

    expect(trackUserAction).toHaveBeenCalledExactlyOnceWith(
      "ApplicantClickedExpiredLinkAgencyWebsite"
    )
  })
})

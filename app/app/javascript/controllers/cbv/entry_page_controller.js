import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "../../utilities/api"

export default class extends Controller {
  static targets = ["consentCheckbox"]

  consent() {
    if (this.consentCheckboxTarget.checked) {
      trackUserAction("ApplicantConsentedToTerms")
    }
  }

  viewHelperText(event) {
    const section = event.currentTarget.dataset.sectionIdentifier
    if (event.currentTarget.getAttribute("aria-expanded") === "false") {
      trackUserAction("ApplicantViewedHelperText", { section })
    }
  }
} 
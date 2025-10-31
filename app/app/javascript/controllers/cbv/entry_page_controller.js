import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "../../utilities/api"

export default class extends Controller {
  static targets = ["consentCheckbox"]

  consent() {
    if (this.consentCheckboxTarget.checked) {
      trackUserAction("ApplicantConsentedToTerms")
    }
  }

  scrollToHowItWorks(event) {
    event.preventDefault()
    trackUserAction("ApplicantClickedLearnHowItWorks")

    document.getElementById("how-it-works")?.scrollIntoView({ behavior: "smooth" })
  }
}

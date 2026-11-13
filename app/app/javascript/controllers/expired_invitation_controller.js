import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "@js/utilities/api.js"

export default class extends Controller {
  trackAgencyWebsiteClick() {
    trackUserAction("ApplicantClickedExpiredLinkAgencyWebsite")
  }
}

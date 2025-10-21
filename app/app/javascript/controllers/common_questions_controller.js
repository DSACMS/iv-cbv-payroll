import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "../utilities/api"

// Shared controller to track Common Questions accordion interactions
export default class extends Controller {
  view(event) {
    const section = event.currentTarget.dataset.sectionIdentifier
    const page = event.currentTarget.dataset.page
    if (event.currentTarget.getAttribute("aria-expanded") === "false") {
      trackUserAction("ApplicantViewedHelpText", { page, section })
    }
  }
}

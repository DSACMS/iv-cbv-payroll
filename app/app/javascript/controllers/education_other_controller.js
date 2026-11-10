import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "@js/utilities/api.js"

export default class extends Controller {
  trackLink(event) {
    trackUserAction("EducationOtherLinkClicked", { link: event.params.link })
  }
}

import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "../utilities/api"

export default class extends Controller {
  static targets = ["content"]

  handleClick(event) {
    if (event.target.href?.includes("#help-modal")) {
      trackUserAction("ApplicantOpenedHelpModal", {
        source: event.target.dataset.source,
      })
      // reset the help modal src on mousedown to ensure the help modal src is reset to "/help"
      document.querySelector("#help_modal_content").src = "/help"
    }
  }

  connect() {
    document.addEventListener("click", this.handleClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClick)
  }
}

import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "../utilities/api"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.handleClick = (event) => {
      if (event.target.href?.includes("#help-modal")) {
        trackUserAction("ApplicantOpenedHelpModal", { source: event.target.dataset.source })
      }
    }

    document.addEventListener("click", this.handleClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClick)
  }
}

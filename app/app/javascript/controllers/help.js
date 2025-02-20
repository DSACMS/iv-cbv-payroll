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

    // Watch for modal visibility changes
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {        
        if (mutation.target.classList.contains('is-hidden')) {
          const frame = document.querySelector('#help_modal_content')
          if (frame) {
            frame.src = '/help'
          }
        }
      })
    })

    const modalElement = document.getElementById('help-modal')
    this.observer.observe(modalElement, {
      attributes: true,
      attributeFilter: ['class']
    })

    document.addEventListener("click", this.handleClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClick)
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

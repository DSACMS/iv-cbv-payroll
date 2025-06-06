import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "../utilities/api"

export default class extends Controller {
  static targets = ["copyLinkButton", "input", "successButton"]

  disconnect() {
    if (this.successTimer) clearTimeout(this.successTimer);
  }

  copy() {
    trackUserAction("ApplicantCopiedInvitationLink")
    if(!this.hasInputTarget) {
      return
    }

    navigator.clipboard.writeText(this.inputTarget.value).then(() => {
      this.showSuccess()
    })
  }

  showSuccess() {
    if(this.hasSuccessButtonTarget) {
      this.successButtonTarget.classList.remove('invisible')
    }
    if(this.hasCopyLinkButtonTarget) {
      this.copyLinkButtonTarget.classList.add('invisible')
    }
  
    // Clear any existing timeout before setting a new one
    if (this.successTimer) clearTimeout(this.successTimer);
    
    this.successTimer = setTimeout(() => {
      if(this.hasSuccessButtonTarget) {
        this.successButtonTarget.classList.add('invisible')
      }
      if(this.hasCopyLinkButtonTarget) {
        this.copyLinkButtonTarget.classList.remove('invisible')
      }
    }, 3000)
  }
} 
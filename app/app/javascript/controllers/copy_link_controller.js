import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "../utilities/api"

export default class extends Controller {
  static targets = ["copyLinkButton", "input", "successButton"]

  connect() {
    if(this.hasCopyLinkButtonTarget){
        this.copyLinkButtonTarget.style.marginTop = "0"
    }
    if(this.hasSuccessButtonTarget) {
      this.successButtonTarget.style.marginTop = "0"
    }
  }

  copy() {
    trackUserAction("ApplicantCopiedInvitationLink")
    const inputElement = this.inputTarget
    
    if (!inputElement) {
      return
    }

    navigator.clipboard.writeText(inputElement.value).then(() => {
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
  
    setTimeout(() => {
      if(this.hasSuccessButtonTarget) {
        this.successButtonTarget.classList.add('invisible')
      }
      if(this.hasCopyLinkButtonTarget) {
        this.copyLinkButtonTarget.classList.remove('invisible')
      }
    }, 3000)
  }
} 
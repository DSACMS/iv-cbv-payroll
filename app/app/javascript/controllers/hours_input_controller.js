import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hoursField", "checkbox"]

  toggle() {
    if (this.checkboxTarget.checked) {
      this.hoursFieldTarget.value = ""
      this.hoursFieldTarget.disabled = true
    } else {
      this.hoursFieldTarget.disabled = false
    }
  }
}

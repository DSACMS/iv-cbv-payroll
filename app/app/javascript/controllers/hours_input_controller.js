import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hoursField", "checkbox"]

  toggle() {
    if (this.checkboxTarget.checked) {
      this.hoursFieldTarget.value = "0"
    } else {
      this.hoursFieldTarget.value = ""
    }
  }

  input() {
    if (this.hoursFieldTarget.value !== "0" && this.hoursFieldTarget.value !== "") {
      this.checkboxTarget.checked = false
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "contactName", "contactEmail", "contactPhone"]

  toggle() {
    const isChecked = this.checkboxTarget.checked

    this.contactNameTarget.disabled = isChecked
    this.contactEmailTarget.disabled = isChecked
    this.contactPhoneTarget.disabled = isChecked

    if (isChecked) {
      this.contactNameTarget.value = "N/A"
      this.contactEmailTarget.value = "N/A"
      this.contactPhoneTarget.value = "N/A"
    } else {
      this.contactNameTarget.value = ""
      this.contactEmailTarget.value = ""
      this.contactPhoneTarget.value = ""
    }
  }
}

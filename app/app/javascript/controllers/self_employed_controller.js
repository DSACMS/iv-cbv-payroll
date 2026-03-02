import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "contactName", "contactEmail", "contactPhone"]

  connect() {
    const isChecked = this.checkboxTarget.checked
    this.setContactFieldsReadonly(isChecked)
  }

  toggle() {
    const isChecked = this.checkboxTarget.checked
    this.setContactFieldsReadonly(isChecked)

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

  setContactFieldsReadonly(readonly) {
    const targets = [this.contactNameTarget, this.contactEmailTarget, this.contactPhoneTarget]
    targets.forEach((target) => {
      target.readOnly = readonly
      target.classList.toggle("usa-input--disabled", readonly)
    })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hoursField", "checkbox", "grossIncomeField"]

  toggle() {
    if (!this.hasCheckboxTarget) return

    if (this.checkboxTarget.checked) {
      this.hoursFieldTarget.value = "0"
      if (this.hasGrossIncomeFieldTarget) {
        this.grossIncomeFieldTarget.value = "0"
      }
    } else {
      this.hoursFieldTarget.value = ""
      if (this.hasGrossIncomeFieldTarget) {
        this.grossIncomeFieldTarget.value = ""
      }
    }
  }

  input() {
    if (!this.hasCheckboxTarget) return

    const hasHours = this.hoursFieldTarget.value !== "0" && this.hoursFieldTarget.value !== ""
    const hasIncome =
      this.hasGrossIncomeFieldTarget &&
      this.grossIncomeFieldTarget.value !== "0" &&
      this.grossIncomeFieldTarget.value !== ""

    if (hasHours || hasIncome) {
      this.checkboxTarget.checked = false
    }
  }
}

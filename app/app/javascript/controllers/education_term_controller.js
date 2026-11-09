import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["enrollmentStatus", "creditHours", "creditHoursField", "noHoursCheckbox"]
  static values = { creditHoursStatuses: Array }

  connect() {
    this.toggleCreditHours()
  }

  enrollmentStatusChanged() {
    if (this.hasNoHoursCheckboxTarget && this.noHoursCheckboxTarget.checked) {
      this.noHoursCheckboxTarget.checked = false
      this.creditHoursFieldTarget.value = ""
    }
    this.toggleCreditHours()
  }

  noHoursChanged() {
    if (this.noHoursCheckboxTarget.checked) this.enrollmentStatusTarget.value = ""
    this.toggleCreditHours()
  }

  toggleCreditHours() {
    const showCreditHours = this.creditHoursStatusesValue.includes(
      this.enrollmentStatusTarget.value
    )

    this.creditHoursTarget.hidden = !showCreditHours
    this.creditHoursFieldTarget.disabled = !showCreditHours
  }
}

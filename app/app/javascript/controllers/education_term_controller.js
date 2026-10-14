import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["enrollmentStatus", "creditHours", "creditHoursField"]
  static values = { creditHoursStatuses: Array }

  connect() {
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

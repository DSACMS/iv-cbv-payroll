import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["form", "additionalJobDetails"];

  connect() {
    this.toggleAdditionalJobDetails();
    this.formTarget.addEventListener('change', this.toggleAdditionalJobDetails.bind(this));
  }

  toggleAdditionalJobDetails() {
    const selectedAdditionalJobsRadio = this.formTarget.querySelector('input[name="additional_jobs"]:checked');
    if (!selectedAdditionalJobsRadio) {
      return
    } else if (selectedAdditionalJobsRadio.value === 'true') {
      this.additionalJobDetailsTarget.style.display = 'block'
    } else if (selectedAdditionalJobsRadio.value === 'false') {
      this.additionalJobDetailsTarget.style.display = 'none'
    }
  }
}

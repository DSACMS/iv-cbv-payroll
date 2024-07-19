import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["form", "additionalJobDetails"];

  connect() {
    console.log("Add job controller connected");
    this.toggleAdditionalJobDetails();
    this.formTarget.addEventListener('change', this.toggleAdditionalJobDetails.bind(this));
  }

  toggleAdditionalJobDetails() {
    const additionalJobsRadio = this.formTarget.querySelector('input[name="additional_jobs"]:checked');
    if (additionalJobsRadio) {
      this.additionalJobDetailsTarget.style.display = additionalJobsRadio.value === 'true' ? 'block' : 'none';
    } else {
      this.additionalJobDetailsTarget.style.display = 'none';
    }
  }
}
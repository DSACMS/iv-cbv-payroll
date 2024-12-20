import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["form", "submitButton"]

  disableSubmit() {
    this.submitButtonTarget.disabled = true;
    this.formTarget.submit()
  }
}

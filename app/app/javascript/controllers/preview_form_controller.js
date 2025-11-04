import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("PreviewFormController connected")
  }

  submit() {
    console.log("PreviewFormController submit called")
    this.element.requestSubmit()
  }
}

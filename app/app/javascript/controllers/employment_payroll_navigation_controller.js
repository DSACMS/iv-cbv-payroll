import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "@js/utilities/api.js"

export default class extends Controller {
  back() {
    trackUserAction("EmploymentBackClicked", { page: "synchronization_failure" })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    dataSourceUrl: String,
  }

  connect() {}

  async initialize() {
    window.open(this.dataSourceUrlValue, "_blank")
  }
}

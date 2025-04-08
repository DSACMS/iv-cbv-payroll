import { Controller } from "@hotwired/stimulus"
import CSRF from "../utilities/csrf"

export default class extends Controller {
  static values = { url: String }
  headers = { Accept: "text/vnd.turbo-stream.html" }

  connect() {
    this.interval = setInterval(() => {
      fetch(this.urlValue, {
        headers: { ...this.headers, "X-CSRF-Token": CSRF.token },
        method: "PATCH",
      })
        .then((response) => response.text())
        .then((html) => {
          // on redirect stop the interval to ensure that the target page page loads before the turboframe gets another command
          if (html.includes('turbo-stream action="redirect')) {
            clearInterval(this.interval)
          }
          return Turbo.renderStreamMessage(html)
        })
    }, 2000)
  }
}

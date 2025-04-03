import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static values = { url: String}
    headers = { 'Accept': 'text/vnd.turbo-stream.html'};


    connect() {
        this.interval = setInterval(() => {
                const csrfToken = document.querySelector("meta[name='csrf-token']").content;
                fetch(this.urlValue, {
                  headers: { ...this.headers, "X-CSRF-Token": csrfToken },
                  method: "PATCH",
                })
                  .then((response) => response.text())
                  .then((html) => {
                      if(html.includes("turbo-stream action=\"redirect")) {
                        clearInterval(this.interval);
                      }
                    return Turbo.renderStreamMessage(html);
                  })
            },
            2000)
    }

    finishedTargetConnected() {
        clearInterval(this.interval)
    }
}
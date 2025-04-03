import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { url: String }
    headers = { 'Accept': 'text/vnd.turbo-stream.html' };

    connect() {
        this.interval = setInterval(() => {
            const csrfToken = document.querySelector("meta[name='csrf-token']").content;
            fetch(this.urlValue, {
                headers: { ...this.headers, "X-CSRF-Token": csrfToken },
                method: "PATCH",
            })
                .then((response) => response.text())
                .then((html) => {
                    // on redirect stop the interval to ensure that the payment details page loads before the turboframe gets another command
                    if (html.includes("turbo-stream action=\"redirect")) {
                        clearInterval(this.interval);
                    }
                    return Turbo.renderStreamMessage(html);
                })
        },
            2000)
    }
}
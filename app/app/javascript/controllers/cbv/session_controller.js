import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  timeoutValue;

  connect() {
    console.log("Session controller connected");
    this.timeoutValue = parseInt(this.modalTarget.dataset.itemTimeoutParam, 10);
    this.setupTimers();
  }

  setupTimers() {
    // Clear existing timers if they exist
    if (this.warningTimer) clearTimeout(this.warningTimer);
    if (this.expirationTimer) clearTimeout(this.expirationTimer);

    // Calculate when to show the warning (5 minutes before expiration)
    const warningDelay = Math.max(this.timeoutValue - 5 * 60, 0) * 1000;
    const expirationDelay = this.timeoutValue * 1000;

    // Set timer for the warning (5 minutes before expiration)
    this.warningTimer = setTimeout(() => {
      document.getElementById("open-session-modal-button").click();
    }, warningDelay);

    // Set timer for the actual session expiration
    this.expirationTimer = setTimeout(() => {
      window.location = `/cbv/reset?timeout=true`;
    }, expirationDelay);
  }

  /*
   reset the timers when the session is extended
   see _timeout_modal.html.erb for the button that triggers this
  */
  resetTimers() {
    this.setupTimers();
  }

  disconnect() {
    console.log("Session controller disconnected");
    if (this.warningTimer) clearTimeout(this.warningTimer);
    if (this.expirationTimer) clearTimeout(this.expirationTimer);
  }
}

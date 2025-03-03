import { Controller } from "@hotwired/stimulus";
import { getDocumentLocale } from "../utilities/getDocumentLocale";

export default class extends Controller {
  static targets = [
    "modal",
  ];

  timeoutValue;

  connect() {
    console.log("Session controller connected");

    this.timeoutValue = parseInt(this.modalTarget.dataset.itemTimeoutParam, 10);

    // The timeoutValue comes from Rails as a number of seconds
    // (e.g., 30.minutes = 1800 seconds)
    
    // Calculate when to show the warning (5 minutes before expiration)
    const warningDelay = Math.max(this.timeoutValue - 5 * 60, 0) * 1000;
    const expirationDelay = this.timeoutValue * 1000;
    
    // Set timer for the warning (5 minutes before expiration)
    this.warningTimer = setTimeout(() => {
      document.getElementById("open-session-modal-button").click();
    }, warningDelay);

    // Set timer for the actual session expiration
    this.expirationTimer = setTimeout(() => {
      const locale = getDocumentLocale();
      window.location = `/${locale}/cbv/entry?end_session=true&user_action=false`;
    }, expirationDelay);
  }

  disconnect() {
    console.log("Session controller disconnected");
    if (this.warningTimer) clearTimeout(this.warningTimer);
    if (this.expirationTimer) clearTimeout(this.expirationTimer);
  }
}

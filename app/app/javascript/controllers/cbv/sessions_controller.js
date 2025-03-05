import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  timeoutValue;
  originalPinwheelZIndex;

  connect() {
    console.log("Session controller connected");
    this.timeoutValue = parseInt(this.modalTarget.dataset.itemTimeoutParam);
    this.setupTimers();
    
    // Add event listeners for modal open/close
    document.getElementById("open-session-modal-button").addEventListener("click", this.handleModalOpen.bind(this));
    const closeButtons = document.querySelectorAll("[data-close-modal]");
    closeButtons.forEach(button => {
      button.addEventListener("click", this.handleModalClose.bind(this));
    });
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
      // Close all modals except the session timeout modal
      const closeButtons = document.querySelectorAll("[data-close-modal]");
      closeButtons.forEach(button => {
        // Skip if this button is inside the session timeout modal
        if (!button.closest('#session-timeout-modal')) {
          button.click();
        }
      });
      document.getElementById("open-session-modal-button").click();
    }, warningDelay);

    // Set timer for the actual session expiration
    this.expirationTimer = setTimeout(() => {
      window.location = `/cbv/session/end?timeout=true`;
    }, expirationDelay);
  }

  handleModalOpen() {
    // Find the pinwheel portal if it exists
    const pinwheelPortal = document.querySelector(".pinwheel-portal");
    if (pinwheelPortal) {
      // Store the original z-index
      this.originalPinwheelZIndex = pinwheelPortal.style.zIndex || getComputedStyle(pinwheelPortal).zIndex;
      pinwheelPortal.style.zIndex = "0";
    }
  }

  handleModalClose() {
    // Restore the original z-index when the session modal is closed
    const pinwheelPortal = document.querySelector(".pinwheel-portal");
    if (pinwheelPortal && this.originalPinwheelZIndex) {
      pinwheelPortal.style.zIndex = this.originalPinwheelZIndex;
    }
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
    
    // Remove event listeners
    document.getElementById("open-session-modal-button")?.removeEventListener("click", this.handleModalOpen);
    const closeButtons = document.querySelectorAll("[data-close-modal]");
    closeButtons.forEach(button => {
      button.removeEventListener("click", this.handleModalClose);
    });
  }
}

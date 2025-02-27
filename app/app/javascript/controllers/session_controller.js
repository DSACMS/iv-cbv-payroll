import { Controller } from "@hotwired/stimulus";
import * as ActionCable from "@rails/actioncable";
import { extendSession, endSession } from "../utilities/sessionService";

const consumer = ActionCable.createConsumer();

export default class extends Controller {
  static values = { cbvFlowId: String };

  subscription = null;

  connect() {
    console.log("Session controller connected");
    if (!this.subscription) {
      this.setupActionCable();
    }

    /*
     * The Stimulus controller data-action="click->session#extendSession"
     * is not working, so we need to add the event listeners manually.
     * The Stimulus action descriptors do work when we add a data-controller="session"
     * to the buttons, but this creates a new controller instance for each button which is
     * not what we want because this will lead to a new websocket connection for each button!
     */

    // extend button
    document.getElementById("extend-session-button").addEventListener(
      "click",
      this.handleExtendSession.bind(this)
    );

    // end button
    document.getElementById("end-session-button").addEventListener(
      "click",
      this.handleEndSession.bind(this)
    );
  }

  disconnect() {
    console.log("Session controller disconnected");
    if (this.subscription) {
      this.subscription.unsubscribe();
      this.subscription = null;
    }

    document.getElementById("extend-session-button").removeEventListener(
      "click",
      this.handleExtendSession.bind(this)
    );

    document.getElementById("end-session-button").removeEventListener(
      "click",
      this.handleEndSession.bind(this)
    );
  }

  setupActionCable() {
    console.log(this.cbvFlowIdValue);
    try {
      this.subscription = consumer.subscriptions.create(
        {
          channel: "SessionChannel",
          cbv_flow_id: this.cbvFlowIdValue,
        },
        {
          connected: () => {},
          disconnected: () => {},
          rejected: () => {},
          received: (data) => {
            this.handleChannelMessage(data);
          },
        }
      );
    } catch (error) {
      console.error("Error setting up ActionCable:", error);
    }
  }

  handleChannelMessage(data) {
    switch (data.event) {
      case "session.warning":
        this.showWarning(data.time_remaining_ms);
        break;

      case "session.extended":
        // Close the modal after a short delay
        setTimeout(() => {
          document.getElementById("close-session-modal-button").click();
        }, 1500);
        break;

      case "session.terminated":
        document.cookie = `${data.cookie_name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
        this.timeout(data.redirect_to || "/");
        break;
    }
  }

  async handleExtendSession() {
    await extendSession(this.subscription);
  }

  async handleEndSession() {
    await endSession(this.subscription);
  }

  showWarning(timeRemainingMs) {
    // Check if the modal is already visible before showing it again
    const isModalAlreadyVisible = this.isModalVisible();
    if (isModalAlreadyVisible) {
      return;
    }

    // Set timeout to redirect after grace period
    setTimeout(() => {
      this.timeout();
    }, timeRemainingMs);

    document.getElementById("open-session-modal-button").click();
  }

  // Helper method to check if the modal is visible
  isModalVisible() {
    const modalElement = document.getElementById("session-timeout-modal");
    return !modalElement.classList.contains("is-hidden");
  }

  async timeout(redirectTo = "/") {
    await endSession(this.subscription);
    window.location = redirectTo;
  }
}

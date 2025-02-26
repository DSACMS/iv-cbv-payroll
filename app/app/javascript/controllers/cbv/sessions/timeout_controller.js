import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'
import { extendSession } from "../../../utilities/sessionService"

export default class extends Controller {
  static targets = ["modal", "trigger", "extendButton"]

  cable = ActionCable.createConsumer();
  subscription = null;

  connect() {
    console.log('Timeout controller connected')
    this.setupActionCable()
  }

  disconnect() {
    console.log('Timeout controller disconnected')
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  setupActionCable() {
    console.log('Setting up ActionCable for session management')
    this.subscription = this.cable.subscriptions.create({ channel: 'SessionChannel' }, {
      connected: () => {
        console.log("Connected to SessionChannel")
      },
      disconnected: () => {
        console.log("Disconnected from SessionChannel")
      },
      received: (data) => {
        console.log("Received message from SessionChannel:", data)
        this.handleChannelMessage(data)
      }
    })
  }

  handleChannelMessage(data) {
    if (data.event === 'session.info') {
      console.log('Received session info from server:', data)
      
      // If session is close to expiring, show warning
      const warningThreshold = 5 * 60 * 1000; // 5 minutes
      if (data.time_remaining_ms <= warningThreshold) {
        console.log('Session close to expiring based on server info, showing warning')
        this.showWarning(data.time_remaining_ms)
      }
    } else if (data.event === 'session.warning') {
      console.log('Session warning received, showing modal')
      this.showWarning(data.time_remaining_ms)
    } else if (data.event === 'session.error') {
      console.error('Session error:', data.message)
      
      // Re-enable the extend button
      if (this.hasExtendButtonTarget) {
        this.extendButtonTarget.disabled = false
      }
    }
  }

  showWarning(timeRemainingMs) {
    // Set a grace period timer based on remaining time or default to 5 minutes
    const gracePeriod = timeRemainingMs || 5 * 60 * 1000; // Use time from server or 5 minutes
    console.log(`Setting grace period timer for ${gracePeriod} ms`)
    
    // Set timeout to redirect after grace period
    setTimeout(() => {
      console.log('Grace period expired, timing out the session')
      this.timeout()
    }, gracePeriod)
    
    if (this.hasTriggerTarget) {
      this.triggerTarget.click()
    } else {
      console.error('Trigger target not found when trying to show warning')
    }
  }

  closeModal() {
    if (this.hasModalTarget) {
      console.log('Closing modal')
      // Use the USWDS modal close method if available
      const modalElement = document.getElementById('cbv-session-timeout-modal')
      if (modalElement && window.uswdsModal) {
        window.uswdsModal.toggleModal(modalElement, false)
      } else {
        // Fallback: add 'display-none' class or similar
        this.modalTarget.classList.add('is-hidden')
      }
      
      // Re-enable the extend button
      if (this.hasExtendButtonTarget) {
        this.extendButtonTarget.disabled = false
      }
    }
  }

  timeout() {
    console.log('Session timed out, redirecting to root')
    window.location = '/'
  }
  
  async extendSession() {
    try {
      // Disable the extend button to prevent multiple clicks
      if (this.hasExtendButtonTarget) {
        this.extendButtonTarget.disabled = true
      }
      
      console.log('Extending session via API call')
      
      // Use the sessionService utility to extend the session
      await extendSession();
      console.log('Session extended successfully')
      
      // Close the modal after a short delay
      setTimeout(() => {
        this.closeModal()
      }, 1500)
    } catch (error) {
      console.error('Failed to extend session:', error)
      
      // Re-enable the extend button
      if (this.hasExtendButtonTarget) {
        this.extendButtonTarget.disabled = false
      }
    }
  }
} 
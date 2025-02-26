import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'
import { extendSession } from "../../../utilities/sessionService"

export default class extends Controller {
  static targets = ["modal", "trigger", "extendButton"]

  cable = ActionCable.createConsumer();
  subscription = null;

  connect() {
    this.setupActionCable()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  setupActionCable() {
    console.log('Setting up ActionCable connection')
    
    try {
      this.subscription = this.cable.subscriptions.create(
        { channel: 'SessionChannel' }, 
        {
          connected: () => {
            console.log('Connected to SessionChannel')
          },
          disconnected: () => {
            console.log('Disconnected from SessionChannel')
          },
          rejected: () => {
            console.error('Connection to SessionChannel was rejected')
          },
          received: (data) => {
            console.log('Received data from SessionChannel:', data)
            this.handleChannelMessage(data)
          }
        }
      )
      
      // Verify subscription was created
      console.log('Subscription created:', this.subscription ? 'Yes' : 'No')
    } catch (error) {
      console.error('Error setting up ActionCable:', error)
    }
  }

  handleChannelMessage(data) {
    console.log('Received message from session channel:', data)
    
    switch (data.event) {
      case 'session.warning':
        this.showWarning(data.time_remaining_ms)
        break
        
      case 'session.extended':
        console.log('Session extended successfully')
        
        // Show success message
        const successStatusMessage = document.getElementById('timeout-status-message')
        if (successStatusMessage) {
          successStatusMessage.textContent = 'Session extended successfully!'
          successStatusMessage.classList.remove('is-hidden')
          
          // Hide message after a few seconds
          setTimeout(() => {
            successStatusMessage.classList.add('is-hidden')
          }, 3000)
        }
        
        // Close the modal after a short delay
        setTimeout(() => {
          this.closeModal()
        }, 1500)
        break
        
      case 'session.info':
        console.log('Received session info:', data)
        // You can implement additional logic here if needed
        break
        
      case 'session.error':
        console.error('Session error:', data.message)
        
        // Re-enable the extend button
        if (this.hasExtendButtonTarget) {
          this.extendButtonTarget.disabled = false
        }
        
        // Show error message
        const errorStatusMessage = document.getElementById('timeout-status-message')
        if (errorStatusMessage) {
          errorStatusMessage.textContent = `Error: ${data.message || 'Failed to extend session'}`
          errorStatusMessage.classList.remove('is-hidden')
        }
        break
        
      case 'session.debug':
        console.debug('Session debug message:', data)
        break
        
      default:
        console.log('Unknown session event:', data.event)
    }
  }

  showWarning(timeRemainingMs) {
    // Check if the modal is already visible before showing it again
    const isModalAlreadyVisible = this.isModalVisible()
    if (isModalAlreadyVisible) {
      console.log('Modal already visible, not showing again')
      return
    }
    
    // Set timeout to redirect after grace period
    setTimeout(() => {
      console.log('Grace period expired, timing out the session')
      this.timeout()
    }, timeRemainingMs)

    console.log('Showing warning modal')
    this.triggerTarget.click()
  }

  // Helper method to check if the modal is visible
  isModalVisible() {
    if (this.hasModalTarget) {
      const modalElement = document.getElementById('cbv-session-timeout-modal')
      if (modalElement && window.uswdsModal) {
        // USWDS modals have a 'is-hidden' class when they're hidden
        return !modalElement.classList.contains('is-hidden')
      } else {
        // Fallback check if not using USWDS
        return !this.modalTarget.classList.contains('is-hidden')
      }
    }
    return false
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
      
      console.log('Extending session via ActionCable')
      
      // Show status message if it exists
      const statusMessage = document.getElementById('timeout-status-message')
      if (statusMessage) {
        statusMessage.textContent = 'Extending session...'
        statusMessage.classList.remove('is-hidden')
      }
      
      // Check if we have an active subscription
      if (!this.subscription) {
        console.error('No active subscription found')
        throw new Error('No active subscription found')
      }
      
      // Pass the existing subscription to extendSession
      await extendSession(this.subscription)
      
      // Note: We don't need to handle success here as it will come through 
      // the ActionCable channel as a 'session.extended' event
    } catch (error) {
      console.error('Failed to extend session:', error)
      
      // Show error message
      const statusMessage = document.getElementById('timeout-status-message')
      if (statusMessage) {
        statusMessage.textContent = `Error: ${error.message || 'Failed to extend session'}`
        statusMessage.classList.remove('is-hidden')
      }
      
      // Re-enable the extend button
      if (this.hasExtendButtonTarget) {
        this.extendButtonTarget.disabled = false
      }
    }
  }
} 
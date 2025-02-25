import { Controller } from "@hotwired/stimulus"
import { sessionAdapter } from "../../../utilities/sessionAdapter"

export default class extends Controller {
  static targets = ["modal", "trigger", "extendButton"]
  static values = {
    warningTime: { type: Number, default: 5000 }, // 5 seconds for testing
    // warningTime: { type: Number, default: 25 * 60 * 1000 }, // 25 minutes in milliseconds
    timeoutTime: { type: Number, default: 30 * 60 * 1000 }  // 30 minutes in milliseconds
  }

  connect() {
    this.resetTimers()
    this.addActivityListeners()
  }

  disconnect() {
    console.log('Timeout controller disconnected')
    this.clearTimers()
    this.removeActivityListeners()
  }

  resetTimers() {
    console.log('Resetting timers')
    this.clearTimers()
    
    console.log('Setting warning timer for', this.warningTimeValue, 'ms')
    this.warningTimer = setTimeout(() => {
      console.log('Warning timer triggered')
      this.showWarning()
    }, this.warningTimeValue)
    
    console.log('Setting timeout timer for', this.timeoutTimeValue, 'ms')
    this.timeoutTimer = setTimeout(() => {
      console.log('Timeout timer triggered')
      this.timeout()
    }, this.timeoutTimeValue)
  }

  clearTimers() {
    if (this.warningTimer) {
      console.log('Clearing warning timer')
      clearTimeout(this.warningTimer)
    }
    if (this.timeoutTimer) {
      console.log('Clearing timeout timer')
      clearTimeout(this.timeoutTimer)
    }
    if (this.activityTimeout) {
      console.log('Clearing activity timeout')
      clearTimeout(this.activityTimeout)
    }
  }

  addActivityListeners() {
    console.log('Adding activity listeners')
    this.boundHandleActivity = this.handleActivity.bind(this)
    ;['mousedown', 'keydown', 'touchstart', 'scroll'].forEach(eventName => {
      document.addEventListener(eventName, this.boundHandleActivity, true)
    })
  }

  removeActivityListeners() {
    console.log('Removing activity listeners')
    if (this.boundHandleActivity) {
      ;['mousedown', 'keydown', 'touchstart', 'scroll'].forEach(eventName => {
        document.removeEventListener(eventName, this.boundHandleActivity, true)
      })
    }
  }

  handleActivity() {
    console.log('Activity detected')
    
    // Clear any pending activity timeout
    if (this.activityTimeout) {
      clearTimeout(this.activityTimeout)
    }

    // Wait 1 second after last activity before resetting timers
    this.activityTimeout = setTimeout(() => {
      this.resetTimers()
    }, 1000)
  }

  showWarning() {
    if (this.hasTriggerTarget) {
      this.triggerTarget.click()
    } else {
      console.error('Trigger target not found when trying to show warning')
    }
  }

  timeout() {
    console.log('Session timed out, redirecting to root')
    window.location = '/'
  }
  
  async extendSession() {
    try {
      console.log('Calling sessionAdapter.extendSession()')
      const response = await sessionAdapter.extendSession()
      console.log('Session extended successfully, response:', response)
      
      // Close the modal
      if (this.hasModalTarget) {
        console.log('Closing modal')
        this.resetTimers()
      }
    } catch (error) {
      console.error('Failed to extend session:', error)
    }
  }
} 
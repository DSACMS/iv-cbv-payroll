import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]
  static values = {
    warningTime: { type: Number, default: 5000 },
    // warningTime: { type: Number, default: 25 * 60 * 1000 }, // 25 minutes in milliseconds
    timeoutTime: { type: Number, default: 30 * 60 * 1000 }  // 30 minutes in milliseconds
  }

  connect() {
    console.log('Timeout controller connected')
    console.log('Warning will show in:', this.warningTimeValue, 'ms')
    console.log('Timeout will occur in:', this.timeoutTimeValue, 'ms')
    this.createModalTrigger()
    this.resetTimers()
    this.addActivityListeners()
  }

  disconnect() {
    console.log('Timeout controller disconnected')
    this.clearTimers()
    this.removeActivityListeners()
    this.removeTriggerButton()
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
      console.log('No activity for 1 second, resetting timers')
      this.resetTimers()
    }, 1000)
  }

  createModalTrigger() {
    // Remove any existing trigger
    this.removeTriggerButton()

    // Create the trigger link matching the help link structure
    const trigger = document.createElement('a')
    trigger.id = 'session-timeout-trigger'
    trigger.href = '#cbv-session-timeout-content'
    trigger.className = 'usa-button'
    trigger.setAttribute('aria-controls', 'cbv-session-timeout-content')
    trigger.dataset.openModal = true // Set to true instead of empty string
    trigger.textContent = 'Open Session Timeout Modal'
    
    // Add to DOM in a visible location
    const container = document.createElement('div')
    container.style.position = 'fixed'
    container.style.top = '20px'
    container.style.right = '20px'
    container.style.zIndex = '9999'
    container.appendChild(trigger)
    document.body.appendChild(container)
    console.log('Created modal trigger:', trigger)
  }

  removeTriggerButton() {
    const existingTrigger = document.getElementById('session-timeout-trigger')
    if (existingTrigger) {
      const container = existingTrigger.parentElement
      if (container) {
        container.remove()
      } else {
        existingTrigger.remove()
      }
      console.log('Removed existing trigger button')
    }
  }

  showWarning() {
    console.log('Attempting to show warning modal')
    const triggerButton = document.getElementById('session-timeout-trigger')
    if (!triggerButton) {
      console.error('Modal trigger button not found')
      return
    }

    console.log('Clicking modal trigger button')
    triggerButton.click()
  }

  timeout() {
    console.log('Session timed out, redirecting to root')
    window.location = '/'
  }
} 
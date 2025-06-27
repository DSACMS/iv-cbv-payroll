const SESSION_STORAGE_CALLBACKS_KEY = "e2eInvokedCallbacks" // Keep in sync with E2e::MockingService
const SESSION_STORAGE_REPLAY_KEY = "e2eCallbacksToInvoke" // Keep in sync with E2e::MockingService

export default class E2ECallbackRecorder {
  originalCallbacks: { [callbackName: string]: Function }

  static Argyle: Argyle = {
    create(params: ArgyleInitializationParams) {
      const recorder = new E2ECallbackRecorder()

      return {
        open: () => {
          if (recorder.isReplayingCallbacks()) {
            recorder.replay(params)
          } else {
            recorder.interceptCallbacks(params)
            return Argyle.create(params).open()
          }
        },
        close: () => {}, // usused by application
      }
    },
  }

  static Pinwheel: Pinwheel = {
    open(params: InitializationParams) {
      const recorder = new E2ECallbackRecorder()

      if (recorder.isReplayingCallbacks()) {
        recorder.replay(params)
      } else {
        recorder.interceptCallbacks(params)
        return Pinwheel.open(params)
      }
    },
    close: () => {}, // unused by the application
  }

  static enabled() {
    if (window.origin === "null") {
      // sessionStorage is not available as we are within an "opaque" origin
      // such as a file:// URL.
      return false
    }

    return (
      !!window.sessionStorage.getItem(SESSION_STORAGE_CALLBACKS_KEY) ||
      !!window.sessionStorage.getItem(SESSION_STORAGE_REPLAY_KEY)
    )
  }

  /*
   * All instance methods below should be aggregator-agnostic.
   */
  constructor() {
    this.originalCallbacks = {}
  }

  /*
   * Intercept callbacks by replacing them with a "recorder" that saves the
   * invocation's arguments into sessionStorage and then calls the original
   * callback method.
   */
  interceptCallbacks(params: ArgyleInitializationParams | InitializationParams) {
    // Assume that all functions in the params object's values are callback
    // methods we should be proxying. This assumes that `params` is flat (i.e.
    // contains no callbacks nested under another key).
    Object.entries(params).forEach(([key, value]: [keyof typeof params, any]) => {
      if (typeof value === "function") {
        console.log("Intercepting callbacks for params key", key)
        this.originalCallbacks[key] = params[key]
        params[key] = this.createCallbackRecorder(key)
      }
    })
  }

  isReplayingCallbacks(): boolean {
    return !!window.sessionStorage.getItem(SESSION_STORAGE_REPLAY_KEY)
  }

  replay(params: ArgyleInitializationParams | InitializationParams) {
    if (!this.isReplayingCallbacks()) {
      console.error("Attempted to replay with no callbacks in ", SESSION_STORAGE_REPLAY_KEY)
    }

    const callbacksToInvoke = JSON.parse(window.sessionStorage.getItem(SESSION_STORAGE_REPLAY_KEY))
    callbacksToInvoke.forEach(
      ({
        callbackName,
        callbackArguments,
      }: {
        callbackName: keyof typeof params
        callbackArguments: any[]
      }) => {
        console.log("Replaying callback", callbackName, "with arguments", callbackArguments)
        params[callbackName].apply(this, callbackArguments)
      }
    )
  }

  createCallbackRecorder(callbackName: string) {
    return (...callbackArguments: any[]) => {
      console.log("Recording invocation of ", callbackName, "with arguments:", ...callbackArguments)

      // Append the invocation of this callback to window.sessionStorage.
      const invokedCallbacksJson = window.sessionStorage.getItem(SESSION_STORAGE_CALLBACKS_KEY)
      const invokedCallbacks = invokedCallbacksJson ? JSON.parse(invokedCallbacksJson) : []
      invokedCallbacks.push({ callbackName, callbackArguments: Array.from(callbackArguments) })
      window.sessionStorage.setItem(SESSION_STORAGE_CALLBACKS_KEY, JSON.stringify(invokedCallbacks))

      // Call the original callback
      this.originalCallbacks[callbackName].apply(this, callbackArguments)
    }
  }
}

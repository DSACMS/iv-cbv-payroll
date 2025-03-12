import { vi, describe, beforeEach, it, expect } from "vitest"
import loadScript from "load-script"

export const mockPinwheelAuthToken = { token: "test-token" }

export const mockPinwheelModule = {
  open: vi.fn(({ onSuccess, onExit, onEvent }) => {
    return {
      triggerSuccessEvent: () => {
        if (onSuccess) {
          onSuccess({ accountId: "account-id", platformId: "platform-id" })
        }
      },
      triggerExitEvent: () => {
        if (onExit) {
          onExit()
        }
      },
      triggerEvent: (eventName, eventPayload) => {
        if (onEvent) {
          onEvent(eventName, eventPayload)
        }
      },
    }
  }),
}

export const mockPinwheel = () => {
  loadScript.mockImplementation((url, callback) => {
    vi.stubGlobal("Pinwheel", mockPinwheelModule)
    callback(null, global.Pinwheel)
  })
}

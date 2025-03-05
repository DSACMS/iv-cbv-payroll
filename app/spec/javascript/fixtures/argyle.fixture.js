import { vi, describe, beforeEach, it, expect } from "vitest"
import loadScript from "load-script"

export const mockArgyleAuthToken = { user: { user_token: "test-token" } }
export const mockArgyleAccountData = { accountId: "account-id", platformId: "platform-id" }

const triggers = ({
  onAccountConnected,
  onClose,
  onAccountCreated,
  onAccountError,
  onAccountRemoved,
  onTokenExpired,
  onError,
}) => ({
  triggerAccountConnected: () => onAccountConnected && onAccountConnected(mockArgyleAccountData),
  triggerClose: () => onClose && onClose(),
  triggerAccountCreated: () => onAccountCreated && onAccountCreated(mockArgyleAccountData),
  triggerAccountError: () => onAccountError && onAccountError(mockArgyleAccountData),
  triggerAccountRemoved: () => onAccountRemoved && onAccountRemoved(mockArgyleAccountData),
  triggerError: () => onError && onError(),
  triggerTokenExpired: (cb) => onTokenExpired && onTokenExpired(cb),
})

export const mockArgyleModule = {
  create: vi.fn((createParams) => {
    return {
      open: vi.fn(() => triggers(createParams)),
    }
  }),
}

export const mockArgyle = () => {
  loadScript.mockImplementation((url, callback) => {
    vi.stubGlobal("Argyle", mockArgyleModule)
    callback(null, global.Argyle)
  })
}

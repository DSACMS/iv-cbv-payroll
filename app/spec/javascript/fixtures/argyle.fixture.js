import { vi, describe, beforeEach, it, expect } from "vitest"
import loadScript from "load-script"

export const mockArgyleAuthToken = { user: { user_token: "test-token" }, isSandbox: true }
export const mockArgyleAccountData = { accountId: "account-id", platformId: "platform-id" }
export const mockArgyleSearchOpenedEvent = { name: "search - opened" }
export const mockApplicantEncounteredArgyleAuthRequiredLoginError = {
  name: "login - opened",
  properties: { errorCode: "auth_required" },
}
export const mockApplicantEncounteredArgyleConnectionUnavailableLoginError = {
  name: "login - opened",
  properties: { errorCode: "connection_unavailable" },
}
export const mockApplicantEncounteredArgyleExpiredCredentialsLoginError = {
  name: "login - opened",
  properties: { errorCode: "expired_credentials" },
}
export const mockApplicantEncounteredArgyleInvalidAuthLoginError = {
  name: "login - opened",
  properties: { errorCode: "invalid_auth" },
}
export const mockApplicantEncounteredArgyleInvalidCredentialsLoginError = {
  name: "login - opened",
  properties: { errorCode: "invalid_credentials" },
}
export const mockApplicantEncounteredArgyleMfaCanceledLoginError = {
  name: "login - opened",
  properties: { errorCode: "mfa_cancelled_by_the_user" },
}
export const mockApplicantViewedArgyleLoginPage = {
  name: "login - opened",
  properties: { errorCode: "other" },
}
export const mockApplicantViewedArgyleProviderConfirmation = { name: "search - link item selected" }
export const mockApplicantUpdatedArgyleSearchTerm = {
  name: "search - term updated",
  term: "search term",
  tab: "tab",
  properties: { term: "search term", tab: "tab" },
}
export const mockApplicantAttemptedArgyleLogin = { name: "login - form submitted" }
export const mockApplicantAccessedArgyleModalMFAScreen = { name: "mfa - opened" }

const triggers = ({
  onAccountConnected,
  onClose,
  onAccountCreated,
  onAccountError,
  onAccountRemoved,
  onTokenExpired,
  onError,
  onUIEvent,
}) => ({
  triggerAccountConnected: () => onAccountConnected && onAccountConnected(mockArgyleAccountData),
  triggerClose: () => onClose && onClose(),
  triggerAccountCreated: () => onAccountCreated && onAccountCreated(mockArgyleAccountData),
  triggerAccountError: () => onAccountError && onAccountError(mockArgyleAccountData),
  triggerAccountRemoved: () => onAccountRemoved && onAccountRemoved(mockArgyleAccountData),
  triggerError: () => onError && onError(),
  triggerTokenExpired: (cb) => onTokenExpired && onTokenExpired(cb),
  triggerUIEvent: (payload) => onUIEvent && onUIEvent(payload),
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

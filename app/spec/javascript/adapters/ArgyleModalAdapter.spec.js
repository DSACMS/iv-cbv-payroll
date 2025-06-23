import { vi, describe, beforeEach, afterEach, it, expect } from "vitest"
import loadScript from "load-script"
import ArgyleModalAdapter from "@js/adapters/ArgyleModalAdapter"
import { fetchArgyleToken, trackUserAction } from "@js/utilities/api"
import { mockArgyle, mockArgyleAuthToken } from "@test/fixtures/argyle.fixture"
import { loadArgyleResource } from "@js/utilities/loadProviderResources.ts"
import {
  mockArgyleSearchOpenedEvent,
  mockApplicantEncounteredArgyleAuthRequiredLoginError,
  mockApplicantEncounteredArgyleConnectionUnavailableLoginError,
  mockApplicantEncounteredArgyleExpiredCredentialsLoginError,
  mockApplicantEncounteredArgyleInvalidAuthLoginError,
  mockApplicantEncounteredArgyleInvalidCredentialsLoginError,
  mockApplicantEncounteredArgyleMfaCanceledLoginError,
  mockApplicantViewedArgyleLoginPage,
  mockApplicantViewedArgyleProviderConfirmation,
  mockApplicantUpdatedArgyleSearchTerm,
  mockApplicantAttemptedArgyleLogin,
  mockApplicantAccessedArgyleModalMFAScreen,
} from "@test/fixtures/argyle.fixture.js"

const modalAdapterArgs = {
  onSuccess: vi.fn(),
  onExit: vi.fn(),
  requestData: {
    responseType: "response-type",
    id: "id",
    providerName: "pinwheel",
    name: "test-name",
    isDefaultOption: true,
  },
}

describe("ArgyleModalAdapter", () => {
  let adapter
  let triggers

  beforeEach(async () => {
    vi.useFakeTimers()
    mockArgyle()
    await loadArgyleResource()
    adapter = new ArgyleModalAdapter()
    adapter.init(modalAdapterArgs)
    triggers = await adapter.open()
  })
  afterEach(() => {})

  describe("open", () => {
    it("calls track user action", async () => {
      expect(trackUserAction).toHaveBeenCalled()
      expect(trackUserAction.mock.calls[0][0]).toBe("ApplicantSelectedEmployerOrPlatformItem")
      expect(trackUserAction.mock.calls[0]).toMatchSnapshot()
    })
    it("fetches token successfully", async () => {
      expect(fetchArgyleToken).toHaveBeenCalledTimes(1)
      expect(fetchArgyleToken).toHaveResolvedWith(mockArgyleAuthToken)
    })
    it("opens argyle modal", async () => {
      expect(Argyle.create).toHaveBeenCalledTimes(1)
    })
    it("passes sandbox flag from token response", async () => {
      expect(Argyle.create).toHaveBeenCalledWith(
        expect.objectContaining({
          sandbox: mockArgyleAuthToken.isSandbox,
        })
      )
      expect(mockArgyleAuthToken.isSandbox).toBe(true)
    })
  })

  describe("event:onSuccess", () => {
    it("calls track user action", async () => {
      await triggers.triggerAccountConnected()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantSucceededWithArgyleLogin")
    })
    it("triggers the modal adapter onSuccess callback", async () => {
      await triggers.triggerAccountConnected()
      expect(modalAdapterArgs.onSuccess).toHaveBeenCalled()
    })
  })
  describe("event:onExit", () => {
    it("triggers the provided onExit callback when modal closed", async () => {
      await triggers.triggerClose()
      expect(modalAdapterArgs.onExit).toHaveBeenCalled()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantClosedArgyleModal")
    })
    it("triggers the provided onExit callback when modal throws error", async () => {
      await triggers.triggerError()
      expect(modalAdapterArgs.onExit).toHaveBeenCalled()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantEncounteredArgyleError")
    })
  })

  describe("event:other", () => {
    it("logs onAccountCreated Event", async () => {
      await triggers.triggerAccountCreated()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantCreatedArgyleAccount")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs onAccountRemoved Event", async () => {
      await triggers.triggerAccountRemoved()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantRemovedArgyleAccount")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs onAccountError Event", async () => {
      await triggers.triggerAccountError()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantEncounteredArgyleAccountError")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("refreshes token onTokenExpired", async () => {
      const updateTokenMock = vi.fn()
      await triggers.triggerTokenExpired(updateTokenMock)
      expect(updateTokenMock).toHaveBeenCalledTimes(1)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantEncounteredArgyleTokenExpired")
    })
    it("logs ApplicantViewedArgyleDefaultProviderSearch Event", async () => {
      await triggers.triggerUIEvent(mockArgyleSearchOpenedEvent)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantViewedArgyleDefaultProviderSearch")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantEncounteredArgyleAuthRequiredLoginError Event", async () => {
      await triggers.triggerUIEvent(mockApplicantEncounteredArgyleAuthRequiredLoginError)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe(
        "ApplicantEncounteredArgyleAuthRequiredLoginError"
      )
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantEncounteredArgyleConnectionUnavailableLoginError Event", async () => {
      await triggers.triggerUIEvent(mockApplicantEncounteredArgyleConnectionUnavailableLoginError)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe(
        "ApplicantEncounteredArgyleConnectionUnavailableLoginError"
      )
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantEncounteredArgyleExpiredCredentialsLoginError Event", async () => {
      await triggers.triggerUIEvent(mockApplicantEncounteredArgyleExpiredCredentialsLoginError)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe(
        "ApplicantEncounteredArgyleExpiredCredentialsLoginError"
      )
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantEncounteredArgyleInvalidAuthLoginError Event", async () => {
      await triggers.triggerUIEvent(mockApplicantEncounteredArgyleInvalidAuthLoginError)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe(
        "ApplicantEncounteredArgyleInvalidAuthLoginError"
      )
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantEncounteredArgyleInvalidCredentialsLoginError Event", async () => {
      await triggers.triggerUIEvent(mockApplicantEncounteredArgyleInvalidCredentialsLoginError)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe(
        "ApplicantEncounteredArgyleInvalidCredentialsLoginError"
      )
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantEncounteredArgyleMfaCanceledLoginError Event", async () => {
      await triggers.triggerUIEvent(mockApplicantEncounteredArgyleMfaCanceledLoginError)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe(
        "ApplicantEncounteredArgyleMfaCanceledLoginError"
      )
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantViewedArgyleLoginPage Event", async () => {
      await triggers.triggerUIEvent(mockApplicantViewedArgyleLoginPage)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantViewedArgyleLoginPage")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantViewedArgyleProviderConfirmation Event", async () => {
      await triggers.triggerUIEvent(mockApplicantViewedArgyleProviderConfirmation)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantViewedArgyleProviderConfirmation")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantUpdatedArgyleSearchTerm Event", async () => {
      await triggers.triggerUIEvent(mockApplicantUpdatedArgyleSearchTerm)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantUpdatedArgyleSearchTerm")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantAttemptedArgyleLogin Event", async () => {
      await triggers.triggerUIEvent(mockApplicantAttemptedArgyleLogin)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantAttemptedArgyleLogin")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs ApplicantAccessedArgyleModalMFAScreen Event", async () => {
      await triggers.triggerUIEvent(mockApplicantAccessedArgyleModalMFAScreen)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantAccessedArgyleModalMFAScreen")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
  })
})

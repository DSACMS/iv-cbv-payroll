import { vi, describe, beforeEach, afterEach, it, expect } from "vitest"
import ArgyleModalAdapter from "@js/adapters/ArgyleModalAdapter"
import { fetchArgyleToken, trackUserAction } from "@js/utilities/api"
import { mockArgyle, mockArgyleAuthToken } from "@test/fixtures/argyle.fixture"
import { loadArgyleResource } from "@js/utilities/loadProviderResources.ts"
import {
  mockApplicantAccessedArgyleModalMFAScreen,
  mockApplicantAttemptedArgyleLogin,
  mockApplicantEncounteredArgyleAuthRequiredLoginError,
  mockApplicantEncounteredArgyleConnectionUnavailableLoginError,
  mockApplicantEncounteredArgyleExpiredCredentialsLoginError,
  mockApplicantEncounteredArgyleInvalidAuthLoginError,
  mockApplicantEncounteredArgyleInvalidCredentialsLoginError,
  mockApplicantEncounteredArgyleMfaCanceledLoginError,
  mockApplicantUpdatedArgyleSearchTerm,
  mockApplicantViewedArgyleLoginPage,
  mockApplicantViewedArgyleProviderConfirmation,
  mockApplicantViewedArgyleUnknownError,
  mockArgyleSearchOpenedEvent,
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
    adapter = new ArgyleModalAdapter(Argyle)
    adapter.init(modalAdapterArgs)
    triggers = await adapter.open()
  })
  afterEach(() => {})

  describe("open", () => {
    it("tracks user action and fetches token", async () => {
      expect(trackUserAction).toHaveBeenCalled()
      expect(trackUserAction.mock.calls[0][0]).toBe("ApplicantSelectedEmployerOrPlatformItem")
      expect(trackUserAction.mock.calls[0]).toMatchSnapshot()
      expect(fetchArgyleToken).toHaveBeenCalledTimes(1)
      expect(fetchArgyleToken).toHaveResolvedWith(mockArgyleAuthToken)
    })

    it("opens argyle modal with sandbox flag and language", async () => {
      expect(Argyle.create).toHaveBeenCalledTimes(1)
      expect(Argyle.create).toHaveBeenCalledWith(
        expect.objectContaining({
          sandbox: mockArgyleAuthToken.isSandbox,
          language: "en",
        })
      )
    })

    it("passes Spanish language when document locale is es", async () => {
      document.documentElement.lang = "es"
      const spanishAdapter = new ArgyleModalAdapter(Argyle)
      spanishAdapter.init(modalAdapterArgs)
      await spanishAdapter.open()

      expect(Argyle.create).toHaveBeenLastCalledWith(expect.objectContaining({ language: "es" }))
    })
  })

  describe("event:onSuccess", () => {
    it("calls track user action", async () => {
      await triggers.triggerAccountConnected()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantSucceededWithArgyleLogin")
      expect(modalAdapterArgs.onSuccess).toHaveBeenCalled()
    })
  })

  describe("event:onExit", () => {
    it("triggers the provided onExit callback when modal closed", async () => {
      await triggers.triggerClose()
      expect(modalAdapterArgs.onExit).toHaveBeenCalled()
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantClosedArgyleModal")

      modalAdapterArgs.onExit.mockClear()
      await triggers.triggerError()
      expect(modalAdapterArgs.onExit).toHaveBeenCalled()
      expect(trackUserAction.mock.calls[2][0]).toBe("ApplicantEncounteredArgyleError")
    })
  })

  describe("event:other", () => {
    it.each([
      ["triggerAccountCreated", "ApplicantCreatedArgyleAccount"],
      ["triggerAccountRemoved", "ApplicantRemovedArgyleAccount"],
      ["triggerAccountError", "ApplicantEncounteredArgyleAccountError"],
    ])("%s logs %s event", async (triggerMethod, expectedEvent) => {
      await triggers[triggerMethod]()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe(expectedEvent)
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })

    it("refreshes token onTokenExpired", async () => {
      const updateTokenMock = vi.fn()
      await triggers.triggerTokenExpired(updateTokenMock)
      expect(updateTokenMock).toHaveBeenCalledTimes(1)
      expect(trackUserAction.mock.calls[1][0]).toBe("ApplicantEncounteredArgyleTokenExpired")
    })

    it.each([
      [mockArgyleSearchOpenedEvent, "ApplicantViewedArgyleDefaultProviderSearch"],
      [
        mockApplicantEncounteredArgyleAuthRequiredLoginError,
        "ApplicantEncounteredArgyleAuthRequiredLoginError",
      ],
      [
        mockApplicantEncounteredArgyleConnectionUnavailableLoginError,
        "ApplicantEncounteredArgyleConnectionUnavailableLoginError",
      ],
      [
        mockApplicantEncounteredArgyleExpiredCredentialsLoginError,
        "ApplicantEncounteredArgyleExpiredCredentialsLoginError",
      ],
      [
        mockApplicantEncounteredArgyleInvalidAuthLoginError,
        "ApplicantEncounteredArgyleInvalidAuthLoginError",
      ],
      [
        mockApplicantEncounteredArgyleInvalidCredentialsLoginError,
        "ApplicantEncounteredArgyleInvalidCredentialsLoginError",
      ],
      [
        mockApplicantEncounteredArgyleMfaCanceledLoginError,
        "ApplicantEncounteredArgyleMfaCanceledLoginError",
      ],
      [mockApplicantViewedArgyleLoginPage, "ApplicantViewedArgyleLoginPage"],
      [mockApplicantViewedArgyleUnknownError, "ApplicantEncounteredArgyleUnknownLoginError"],
      [mockApplicantViewedArgyleProviderConfirmation, "ApplicantViewedArgyleProviderConfirmation"],
      [mockApplicantUpdatedArgyleSearchTerm, "ApplicantUpdatedArgyleSearchTerm"],
      [mockApplicantAttemptedArgyleLogin, "ApplicantAttemptedArgyleLogin"],
      [mockApplicantAccessedArgyleModalMFAScreen, "ApplicantAccessedArgyleModalMFAScreen"],
    ])("logs %s UI event", async (mockEvent, expectedEvent) => {
      await triggers.triggerUIEvent(mockEvent)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe(expectedEvent)
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
  })
})

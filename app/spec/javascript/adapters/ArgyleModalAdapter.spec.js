import { vi, describe, beforeEach, afterEach, it, expect } from "vitest"
import loadScript from "load-script"
import ArgyleModalAdapter from "@js/adapters/ArgyleModalAdapter"
import { fetchArgyleToken, trackUserAction } from "@js/utilities/api"
import { mockArgyle, mockArgyleAuthToken } from "@test/fixtures/argyle.fixture"
import { loadArgyleResource } from "@js/utilities/loadProviderResources.ts"

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
    })
  })

  describe("event:onSucces", () => {
    it("calls track user action", async () => {
      await triggers.triggerAccountConnected()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ArgyleSuccess")
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
      expect(trackUserAction.mock.calls[1][0]).toBe("ArgyleCloseModal")
    })
    it("triggers the provided onExit callback when modal throws error", async () => {
      await triggers.triggerError()
      expect(modalAdapterArgs.onExit).toHaveBeenCalled()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ArgyleError")
    })
  })

  describe("event:other", () => {
    it("logs onAccountCreated Event", async () => {
      await triggers.triggerAccountCreated()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ArgyleAccountCreated")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs onAccountRemoved Event", async () => {
      await triggers.triggerAccountRemoved()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ArgyleAccountRemoved")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("logs onAccountError Event", async () => {
      await triggers.triggerAccountError()
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ArgyleAccountError")
      expect(trackUserAction.mock.calls[1][1]).toMatchSnapshot()
    })
    it("refreshes token onTokenExpired", async () => {
      const updateTokenMock = vi.fn()
      await triggers.triggerTokenExpired(updateTokenMock)
      expect(updateTokenMock).toHaveBeenCalledTimes(1)
      expect(trackUserAction).toHaveBeenCalledTimes(2)
      expect(trackUserAction.mock.calls[1][0]).toBe("ArgyleTokenExpired")
    })
  })
})

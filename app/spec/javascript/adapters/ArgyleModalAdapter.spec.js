import { vi, describe, beforeEach, afterEach, it, expect } from "vitest";
import loadScript from "load-script";
import ArgyleModalAdapter from "@js/adapters/ArgyleModalAdapter";
import { fetchArgyleToken, trackUserAction } from '@js/utilities/api';
import { mockArgyle, mockArgyleAuthToken } from "@test/fixtures/argyle.fixture";

const MOCK_ARGYLE_ERROR = "Failed to load SCRIPT"

const modalAdapterArgs = {
    onSuccess: vi.fn(),
    requestData: {
        responseType: "response-type",
        id: "id",
        providerName: "pinwheel",
        name: "test-name",
        isDefaultOption: true,
    }
}



describe('ArgyleModalAdapter', () => {
    let adapter;
    let triggers;
        
    beforeEach(async () => {
        mockArgyle();
        adapter = new ArgyleModalAdapter()
        adapter.load()
        adapter.init(modalAdapterArgs)
        triggers = await adapter.open()
    })
    afterEach(() => {
    })

    describe('open', () => {
        it('calls track user action', async () => {
            expect(trackUserAction).toHaveBeenCalled()
            expect(trackUserAction.mock.calls[0][0]).toBe('ApplicantSelectedEmployerOrPlatformItem')
            expect(trackUserAction.mock.calls[0]).toMatchSnapshot()
        })
        it('fetches token successfully', async () => {
            expect(fetchArgyleToken).toHaveBeenCalledTimes(1)
            expect(fetchArgyleToken).toHaveResolvedWith(mockArgyleAuthToken)
        })
        it('opens argyle modal', async () => {
            expect(Argyle.create).toHaveBeenCalledTimes(1)
        })
    })

    describe('Account Connected (success event)', () => {
        it('calls track user action', async() => {
            await triggers.triggerAccountConnected()
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('ArgyleSuccess')
        })
        it('triggers the modal adapter onSuccess callback', async () => {
            await triggers.triggerAccountConnected()
            expect(modalAdapterArgs.onSuccess).toHaveBeenCalled()
        })
    })
    describe.skip('onExit', () => {
        it('triggers the provided onExit callback', async () => {
            await triggers.triggerSuccessEvent()
            expect(pinwheelModalAdapterArgs.onSuccess).toHaveBeenCalled()
        })
    })
    describe.skip('onEvent', () => {
        it('logs screen_transition.LOGIN Event', async () => {
            await triggers.triggerEvent("screen_transition", { "screenName": "LOGIN", selectedEmployerName: "ACME Inc", selectedPlatformName: "ADP" })
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelShowLoginPage')
        })
        it('logs screen_transition.PROVIDER_CONFIRMATION event', async () => {
            await triggers.triggerEvent("screen_transition", { "screenName": "PROVIDER_CONFIRMATION"})
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelShowProviderConfirmationPage')
        })
        it('logs screen_transition.SEARCH_DEFAULT event', async () => {
            await triggers.triggerEvent("screen_transition", { "screenName": "SEARCH_DEFAULT"})
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelShowDefaultProviderSearch')
        })
        it('logs screen_transition.EXIT_CONFIRMATION event', async () => {
            await triggers.triggerEvent("screen_transition", { "screenName": "EXIT_CONFIRMATION"})
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelAttemptClose')
        })
        it('logs login_attempt event', async () => {
            await triggers.triggerEvent("login_attempt")
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelAttemptLogin')
        })
        it('logs error event', async () => {
            await triggers.triggerEvent("error", { type: "error-type", "code": "code", "message":"default message"})
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelError')
            expect(trackUserAction.mock.calls[1][1]['type']).toBe('error-type')
        })
        it('logs exit event', async () => {
            await triggers.triggerEvent("exit")
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelCloseModal')
        })
    })
})
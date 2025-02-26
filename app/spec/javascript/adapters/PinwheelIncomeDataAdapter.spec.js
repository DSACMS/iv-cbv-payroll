import { vi, describe, beforeEach, afterEach, it, expect } from "vitest";
import loadScript from "load-script";
import PinwheelModalAdapter from "@js/adapters/PinwheelModalAdapter";
import { fetchToken, trackUserAction } from '@js/utilities/api';
import { mockPinwheel } from "@test/fixtures/pinwheel.fixture";

const mockPinwheelAuthToken = { token: 'test-token' };
const MOCK_PINWHEEL_ERROR = "Failed to load SCRIPT"

const pinwheelModalAdapterArgs = {
    onSuccess: vi.fn(),
    requestData: {
        responseType: "response-type",
        id: "id",
        providerName: "pinwheel",
        name: "test-name",
        isDefaultOption: true,
    }
}



describe('PinwheelModalAdapter', () => {
    let adapter;
    let triggers;
        
    beforeEach(async () => {
        mockPinwheel();
        adapter = new PinwheelModalAdapter()
        adapter.load()
        adapter.init(pinwheelModalAdapterArgs)
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
            expect(fetchToken).toHaveBeenCalledTimes(1)
            expect(fetchToken).toHaveBeenCalledWith("response-type", "id", "en")
            expect(fetchToken).toHaveResolvedWith({ token: 'test-token' })
        })
        it('opens Pinwheel modal', async () => {
            expect(Pinwheel.open).toHaveBeenCalledTimes(1)
        })
    })

    describe('onSuccess', () => {
        it('calls track user action', async() => {
            await triggers.triggerSuccessEvent()
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelSuccess')
        })
        it('triggers the provided onSuccess callback', async () => {
            await triggers.triggerSuccessEvent()
            expect(pinwheelModalAdapterArgs.onSuccess).toHaveBeenCalled()
        })
    })
    describe('onExit', () => {
        it('triggers the provided onExit callback', async () => {
            await triggers.triggerSuccessEvent()
            expect(pinwheelModalAdapterArgs.onSuccess).toHaveBeenCalled()
        })
    })
    describe('onEvent', () => {
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
import { vi, describe, beforeEach, afterEach, it, expect } from "vitest";
import loadScript from "load-script";
import PinwheelIncomeDataAdapter from "@js/adapters/PinwheelIncomeDataAdapter";
import { fetchToken, trackUserAction } from '@js/utilities/api';
import { mockPinwheel } from "@test/fixtures/pinwheel.fixture";

const mockPinwheelAuthToken = { token: 'test-token' };
const MOCK_PINWHEEL_ERROR = "Failed to load SCRIPT"

const pinwheelIncomeDataAdapterArgs = {
    onSuccess: vi.fn(),
    requestData: {
        responseType: "response-type",
        id: "id",
        provider: "pinwheel",
        name: "test-name",
        isDefaultOption: true,
    }
}



describe('PinwheelIncomeDataAdapter', () => {
    let adapter;
    let triggers;
        
    beforeEach(async () => {
        mockPinwheel();
        adapter = new PinwheelIncomeDataAdapter(pinwheelIncomeDataAdapterArgs)
        triggers = await adapter.open()
    })
    afterEach(() => {
    })

    describe('open', () => {
        it('should call track user action', async () => {
            expect(trackUserAction).toHaveBeenCalled()
            expect(trackUserAction.mock.calls[0][0]).toBe('ApplicantSelectedEmployerOrPlatformItem')
            expect(trackUserAction.mock.calls[0]).toMatchSnapshot()
        })
        it('should fetch token successfully', async () => {
            expect(fetchToken).toHaveBeenCalledTimes(1)
            expect(fetchToken).toHaveBeenCalledWith("response-type", "id", "en")
            expect(fetchToken).toHaveResolvedWith({ token: 'test-token' })
        })
        it('should open Pinwheel modal', async () => {
            expect(Pinwheel.open).toHaveBeenCalledTimes(1)
        })
    })

    describe('onSuccess', () => {
        it('should call track user action', async() => {
            await triggers.triggerSuccessEvent()
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelSuccess')
        })
        it('should trigger the provided onSuccess callback', async () => {
            await triggers.triggerSuccessEvent()
            expect(pinwheelIncomeDataAdapterArgs.onSuccess).toHaveBeenCalled()
        })
    })
    describe('onExit', () => {
        it('should trigger the provided onExit callback', async () => {
            await triggers.triggerSuccessEvent()
            expect(pinwheelIncomeDataAdapterArgs.onSuccess).toHaveBeenCalled()
        })
    })
    describe('onEvent', () => {
        it('should log screen_transition.LOGIN Event', async () => {
            await triggers.triggerEvent("screen_transition", { "screenName": "LOGIN", selectedEmployerName: "ACME Inc", selectedPlatformName: "ADP" })
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelShowLoginPage')
        })
        it('should log screen_transition.PROVIDER_CONFIRMATION event', async () => {
            await triggers.triggerEvent("screen_transition", { "screenName": "PROVIDER_CONFIRMATION"})
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelShowProviderConfirmationPage')
        })
        it('should log screen_transition.SEARCH_DEFAULT event', async () => {
            await triggers.triggerEvent("screen_transition", { "screenName": "SEARCH_DEFAULT"})
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelShowDefaultProviderSearch')
        })
        it('should log screen_transition.EXIT_CONFIRMATION event', async () => {
            await triggers.triggerEvent("screen_transition", { "screenName": "EXIT_CONFIRMATION"})
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelAttemptClose')
        })
        it('should log login_attempt event', async () => {
            await triggers.triggerEvent("login_attempt")
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelAttemptLogin')
        })
        it('should log error event', async () => {
            await triggers.triggerEvent("error", { type: "error-type", "code": "code", "message":"default message"})
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelError')
            expect(trackUserAction.mock.calls[1][1]['type']).toBe('error-type')
        })
        it('should log exit event', async () => {
            await triggers.triggerEvent("exit")
            expect(trackUserAction).toHaveBeenCalledTimes(2)
            expect(trackUserAction.mock.calls[1][0]).toBe('PinwheelCloseModal')
        })
    })
})
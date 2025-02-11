import { vi, describe, beforeEach, afterEach, it, expect } from "vitest";
import * as pinwheel from "@js/utilities/pinwheel";
import loadScript from "load-script";
import PinwheelProviderWrapper from "@js/providers/pinwheel";
import { fetchToken, trackUserAction } from '@js/utilities/api';

const MOCK_PINWHEEL_AUTH_OBJECT = { token: 'test-token' };
const MOCK_PINWHEEL_ERROR = "Failed to load SCRIPT"

const mockPinwheelModule = { 
    open: vi.fn(({onSuccess}) => {
        return  {
            triggerSuccessEvent: () => {
                if (onSuccess) {
                    onSuccess({ accountId: 'account-id', platformId: 'platform-id'});
                }
            }
        }
    }),
} 

const pinwheelProviderWrapperArgs = {
    onSuccess: vi.fn(),
}


const MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION = (url, callback) => {
    vi.stubGlobal('Pinwheel', mockPinwheelModule)
    callback(null, global.Pinwheel)
}

vi.mock('load-script', () => {
    return {
        default: vi.fn(),
    }
})

vi.mock('@js/utilities/api', async () => {
    const apiModule = await vi.importActual('@js/utilities/api')
    return {
        ...apiModule,
        trackUserAction: vi.fn((eventName, eventPayload) => Promise.resolve()),
        fetchToken: vi.fn(() => Promise.resolve(MOCK_PINWHEEL_AUTH_OBJECT)),
    }
})

describe('PinwheelWrapper', () => {
    let pinwheelWrapper;
    let triggers;
        
    beforeEach(async () => {
        loadScript.mockImplementation(MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION)
        pinwheelWrapper = new PinwheelProviderWrapper(pinwheelProviderWrapperArgs)
        triggers = await pinwheelWrapper.open("response-type", "id", "name", false)
    })
    afterEach(() => {
        loadScript.mockReset()
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

            expect(pinwheelProviderWrapperArgs.onSuccess).
        })
    })
})
/*


describe.skip('loadPinwheel', () => {
    let pinwheelWrapper;

    beforeEach(() => {
        pinwheelWrapper = new PinwheelProviderWrapper()
    })
    it('calls API endpoint', () => {
        expect(loadScript).toBeCalledTimes(1)
    });
    it('uses the correct pinwheel api endpoint', () => {
        expect(loadScript.mock.calls[0][0]).toMatch('cdn.getpinwheel.com')
        expect(loadScript.mock.calls[0][0]).toMatch('pinwheel-v3')
    })
    it.skip('should resolve with Pinwheel object when script loads successfully', async () => {
        loadScript.mockImplementation(MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION)
        expect(window.Pinwheel).toBeDefined()
        expect(Pinwheel).toBe(MOCK_PINWHEEL_MODULE)
    })
    it.skip('rejects loading on error', async () => {
        loadScript.mockImplementation((url, callback) => {
            callback(new Error(MOCK_PINWHEEL_ERROR), null)
        })
        await expect(pinwheel.loadPinwheel).rejects.toThrow(MOCK_PINWHEEL_ERROR)
    })
    afterEach(() => {
        loadScript.mockReset()
    })
})

describe('open', () => {
    it.skip('opens Pinwheel modal', async () => {
        loadScript.mockImplementation(MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION)
        const pinwheelWrapper = new PinwheelProviderWrapper()
        pinwheelWrapper.open("response-type", "id", "name", true)
        expect(Pinwheel.open).toBeCalledTimes(1)
        
        //expect(Pinwheel.open.mock.calls[0]).toMatchSnapshot()
    })
    it('sends track user action event', async () => {
        loadScript.mockImplementation(MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION)
        const pinwheelWrapper = new PinwheelProviderWrapper()
        expect(trackUserAction).toBeCalledTimes(1);
    })
    afterEach(() => {
        loadScript.mockReset()
    })
})*/
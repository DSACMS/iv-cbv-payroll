import { vi, describe, beforeEach, afterEach, it, expect } from 'vitest'
import * as pinwheel from './pinwheel'
import loadScript from 'load-script'

const MOCK_PINWHEEL_MODULE = { 
    open: vi.fn()
} 
const MOCK_PINWHEEL_ERROR = "Failed to load SCRIPT"

const MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION = (url, callback) => {
    vi.stubGlobal('Pinwheel', MOCK_PINWHEEL_MODULE)
    callback(null, window.Pinwheel)
}

const MOCK_PINWHEEL_INIT_CALLBACKS = {
    onError: vi.fn(),
    onSuccess: vi.fn()
}

vi.mock('load-script', () => {
    return {
        default: vi.fn(),
    }
})

describe('loadPinwheel', () => {
    it('calls API endpoint', () => {
        pinwheel.loadPinwheel()
        expect(loadScript).toBeCalledTimes(1)
    });
    it('uses the correct pinwheel api endpoint', () => {
        pinwheel.loadPinwheel()
        expect(loadScript.mock.calls[0][0]).toMatch('cdn.getpinwheel.com')
        expect(loadScript.mock.calls[0][0]).toMatch('pinwheel-v3')
    })
    it('should resolve with Pinwheel object when script loads successfully', async () => {
        loadScript.mockImplementation(MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION)
        const Pinwheel = await pinwheel.loadPinwheel()
        expect(Pinwheel).toBeDefined()
        expect(Pinwheel).toBe(MOCK_PINWHEEL_MODULE)
    })
    it('rejects loading on error', async () => {
        loadScript.mockImplementation((url, callback) => {
            callback(new Error(MOCK_PINWHEEL_ERROR), null)
        })
        await expect(pinwheel.loadPinwheel).rejects.toThrow(MOCK_PINWHEEL_ERROR)
    })
    afterEach(() => {
        loadScript.mockReset()
    })
})

describe('initializePinwheel', () => {
    it('opens Pinwheel modal', async () => {
        loadScript.mockImplementation(MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION)
        const Pinwheel = await pinwheel.loadPinwheel()
        pinwheel.initializePinwheel(Pinwheel, "link-token", MOCK_PINWHEEL_INIT_CALLBACKS)
        expect(Pinwheel.open).toBeCalledTimes(1)
        expect(Pinwheel.open.mock.calls[0]).toMatchSnapshot()
    })
    afterEach(() => {
        loadScript.mockReset()
    })
})
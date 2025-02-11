import { vi, describe, beforeEach, it, expect } from 'vitest'
import EmployerSearchController from '@js/controllers/cbv/employer_search'
import { fetchToken, trackUserAction } from '@js/utilities/api';
import loadScript from "load-script";

const MOCK_PINWHEEL_AUTH_OBJECT = { token: 'test-token' };


const mockPinwheelModule = { 
    open: vi.fn(({onSuccess, onExit, onEvent}) => {
        return  {
            triggerSuccessEvent: () => {
                if (onSuccess) {
                    onSuccess({ accountId: 'account-id', platformId: 'platform-id'});
                }
            },
            triggerExitEvent: () => {
                if (onExit) {
                    onExit();
                }
            },
            triggerEvent: (eventName, eventPayload) => {
                if (onEvent) {
                    onEvent(eventName, eventPayload)
                }
            }
        }
    }),
} 

const MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION = (url, callback) => {
    vi.stubGlobal('Pinwheel', mockPinwheelModule)
    callback(null, global.Pinwheel)
}

const Pinwheel = {
    open: vi.fn()
}

vi.mock('@js/utilities/api', async() => {
    const apiModule = await vi.importActual('@js/utilities/api')
    return {
        ...apiModule,
        trackUserAction: vi.fn((eventName, eventPayload) => Promise.resolve()),
        fetchToken: vi.fn(() => Promise.resolve(MOCK_PINWHEEL_AUTH_OBJECT)),
    }
})

vi.mock('load-script', () => {
    return {
        default: vi.fn(),
    }
})

describe('EmployerSearchController', () => {
    let stimulusElement;

    beforeEach(() => {
        stimulusElement = document.getElementById('employer-search-button')
        stimulusElement = document.createElement('button');
        stimulusElement.setAttribute('data-controller', 'cbv-employer-search')
        //stimulusElement.setAttribute('data-action', 'cbv-employer-search#select')
        document.body.appendChild(stimulusElement)

        vi.spyOn(stimulusElement, 'addEventListener')
        vi.spyOn(stimulusElement, 'removeEventListener')

        window.Stimulus.register('cbv-employer-search', EmployerSearchController);
    });

    afterEach(() => {
        document.body.innerHTML = "";
    })

    it('loads Pinwheel modal from external website on init', () => {
        expect(loadScript).toBeCalledTimes(1)
    });

    it('adds turbo:frame-missing listener on connect()', () => {
        expect(stimulusElement.addEventListener).toBeCalledTimes(1)
        expect(stimulusElement.addEventListener).toHaveBeenCalledWith("turbo:frame-missing", expect.any(Function))
    });

    it.skip('removes turbo:frame-missing listener on disconnect()', () => {
        expect(stimulusElement.removeEventListener).toBeCalledTimes(1)
        expect(stimulusElement.removeEventListener).toHaveBeenCalledWith("turbo:frame-missing", expect.any(Function))
    })

})

describe('EmployerSearchController button click', () => {
    let stimulusElement;

    beforeEach(async () => {
        loadScript.mockImplementation(MOCK_LOAD_PINWHEEL_SUCCESS_IMPLEMENTATION)

        stimulusElement = document.getElementById('employer-search-button')
        stimulusElement = document.createElement('button');
        stimulusElement.setAttribute('data-controller', 'cbv-employer-search')
        stimulusElement.setAttribute('data-action', 'cbv-employer-search#select')
        stimulusElement.setAttribute('data-response-type', 'csv')
        stimulusElement.setAttribute('data-id', 'test-id')
        stimulusElement.setAttribute('data-is-default-option', false)
        stimulusElement.setAttribute('data-name', 'test-name')
        document.body.appendChild(stimulusElement)

        vi.spyOn(stimulusElement, 'addEventListener')
        vi.spyOn(stimulusElement, 'removeEventListener')

        await window.Stimulus.register('cbv-employer-search', EmployerSearchController);
    });

    afterEach(() => {
        document.body.innerHTML = "";
    })

    it('calls trackUserAction with data attributes from employer_search html', () => {
        stimulusElement.click();
        expect(trackUserAction).toBeCalledTimes(1);
        expect(trackUserAction.mock.calls[0]).toMatchSnapshot()
    });
    it('fetches Pinwheel token', async() => {
        await stimulusElement.click();
        expect(fetchToken).toBeCalledTimes(1);
        expect(await fetchToken.mock.results[0].value).toBe(MOCK_PINWHEEL_AUTH_OBJECT)
        expect(fetchToken.mock.calls[0]).toMatchSnapshot()
    });
})
import { vi, describe, beforeEach, it, expect } from 'vitest'
import EmployerSearchController from '@js/controllers/cbv/employer_search'
import { loadPinwheel, initializePinwheel} from '@js/utilities/pinwheel'
import { fetchToken, trackUserAction } from '@js/utilities/api';

const MOCK_PINWHEEL_AUTH_OBJECT = { token: 'test-token' };

const Pinwheel = {
    open: vi.fn()
}
vi.mock('@js/utilities/pinwheel', async () => {
    const pinwheelModule = await vi.importActual('@js/utilities/pinwheel')
    return {
        ...pinwheelModule,
        loadPinwheel: vi.fn(() => Promise.resolve(Pinwheel)),
        initializePinwheel: vi.fn()
    }
  })

vi.mock('@js/utilities/api', async() => {
    const apiModule = await vi.importActual('@js/utilities/api')
    return {
        ...apiModule,
        trackUserAction: vi.fn((eventName, eventPayload) => Promise.resolve()),
        fetchToken: vi.fn(() => Promise.resolve(MOCK_PINWHEEL_AUTH_OBJECT)),
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

    it('calls loadPinwheel on init', () => {
        expect(loadPinwheel).toBeCalledTimes(1)
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

    it('initializes Pinwheel', async () => {
        await stimulusElement.click();
    })
})
import { vi, describe, beforeEach, it, expect } from 'vitest'
import EmployerSearchController from '@js/controllers/cbv/employer_search'
import { fetchToken, trackUserAction } from '@js/utilities/api';
import loadScript from "load-script";
import { mockPinwheel, mockPinwheelAuthToken } from '@test/fixtures/pinwheel.fixture';

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

    it('removes turbo:frame-missing listener on disconnect()', async() => {
        await stimulusElement.remove();
        expect(stimulusElement.removeEventListener).toBeCalledTimes(1)
        expect(stimulusElement.removeEventListener.mock.calls[0][0]).toBe("turbo:frame-missing")
    })

})

describe('EmployerSearchController button click', () => {
    let stimulusElement;

    beforeEach(async () => {
        mockPinwheel();

        stimulusElement = document.getElementById('employer-search-button')
        stimulusElement = document.createElement('button');
        stimulusElement.setAttribute('data-controller', 'cbv-employer-search')
        stimulusElement.setAttribute('data-action', 'cbv-employer-search#select')
        stimulusElement.setAttribute('data-response-type', 'csv')
        stimulusElement.setAttribute('data-id', 'test-id')
        stimulusElement.setAttribute('data-is-default-option', false)
        stimulusElement.setAttribute('data-name', 'test-name')
        stimulusElement.setAttribute('data-provider', 'pinwheel')
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
        expect(await fetchToken.mock.results[0].value).toStrictEqual(mockPinwheelAuthToken)
        expect(fetchToken.mock.calls[0]).toMatchSnapshot()
    });
})
import { vi, describe, beforeEach, it, expect } from 'vitest'
import EmployerSearchController from '@js/controllers/cbv/employer_search'
import { fetchToken, trackUserAction } from '@js/utilities/api';
import loadScript from "load-script";
import { mockPinwheel, mockPinwheelAuthToken } from '@test/fixtures/pinwheel.fixture';

describe('EmployerSearchController', () => {
    let stimulusElement;

    beforeEach(() => {
        stimulusElement = document.createElement('button');
        stimulusElement.setAttribute('data-controller', 'cbv-employer-search')
        document.body.appendChild(stimulusElement)

        vi.spyOn(stimulusElement, 'addEventListener')
        vi.spyOn(stimulusElement, 'removeEventListener')

        window.Stimulus.register('cbv-employer-search', EmployerSearchController);
    });

    afterEach(() => {
        document.body.innerHTML = "";
    })


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

        stimulusElement = document.createElement('button');
        stimulusElement.setAttribute('data-controller', 'cbv-employer-search')
        stimulusElement.setAttribute('data-action', 'cbv-employer-search#select')
        stimulusElement.setAttribute('data-response-type', 'csv')
        stimulusElement.setAttribute('data-id', 'test-id')
        stimulusElement.setAttribute('data-is-default-option', false)
        stimulusElement.setAttribute('data-name', 'test-name')
        stimulusElement.setAttribute('data-provider-name', 'pinwheel')
        document.body.appendChild(stimulusElement)

        vi.spyOn(stimulusElement, 'addEventListener')
        vi.spyOn(stimulusElement, 'removeEventListener')

        await window.Stimulus.register('cbv-employer-search', EmployerSearchController);
    });

    afterEach(() => {
        document.body.innerHTML = "";
    })

    it('loads Pinwheel modal from external website on click', () => {
        stimulusElement.click();
        expect(loadScript).toBeCalledTimes(1)
    });
    
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

describe('EmployerSearchController multiple instances on same page!', () => {
    let stimulusElement1;
    let stimulusElement2;

    beforeEach(async () => {
        mockPinwheel();

        stimulusElement1 = document.getElementById('employer-search-button-1')
        stimulusElement1 = document.createElement('button');
        stimulusElement1.setAttribute('data-controller', 'cbv-employer-search')
        stimulusElement1.setAttribute('data-action', 'cbv-employer-search#select')
        stimulusElement1.setAttribute('data-response-type', 'csv')
        stimulusElement1.setAttribute('data-id', 'test-id-1')
        stimulusElement1.setAttribute('data-is-default-option', false)
        stimulusElement1.setAttribute('data-name', 'test-name-1')
        stimulusElement1.setAttribute('data-provider-name', 'pinwheel')

        stimulusElement2 = document.getElementById('employer-search-button-2')
        stimulusElement2 = document.createElement('button');
        stimulusElement2.setAttribute('data-controller', 'cbv-employer-search')
        stimulusElement2.setAttribute('data-action', 'cbv-employer-search#select')
        stimulusElement2.setAttribute('data-response-type', 'csv')
        stimulusElement2.setAttribute('data-id', 'test-id-2')
        stimulusElement2.setAttribute('data-is-default-option', false)
        stimulusElement2.setAttribute('data-name', 'test-name-2')
        stimulusElement2.setAttribute('data-provider-name', 'pinwheel')


        document.body.appendChild(stimulusElement1)
        document.body.appendChild(stimulusElement2)

        vi.spyOn(stimulusElement1, 'addEventListener')
        vi.spyOn(stimulusElement1, 'removeEventListener')
        vi.spyOn(stimulusElement2, 'addEventListener')
        vi.spyOn(stimulusElement2, 'removeEventListener')

        await window.Stimulus.register('cbv-employer-search', EmployerSearchController);
    });

    afterEach(() => {
        document.body.innerHTML = "";
    })

    it('calls trackUserAction each time element is clicked', async () => {
        await stimulusElement1.click();
        await stimulusElement1.click();
        await stimulusElement2.click();
        await stimulusElement1.click();
        await stimulusElement1.click();


        expect(trackUserAction).toBeCalledTimes(5);
        expect(trackUserAction.mock.calls[0]).toMatchSnapshot()
    });
    it('fetches Pinwheel token each time the button is clicked', async() => {
        await stimulusElement1.click();
        await stimulusElement2.click();
        await stimulusElement1.click();
        await stimulusElement1.click();

        expect(fetchToken).toBeCalledTimes(4);
        expect(await fetchToken.mock.results[0].value).toStrictEqual(mockPinwheelAuthToken)
        expect(fetchToken.mock.calls[0]).toMatchSnapshot()
    });
    it('removal of one button does not impact function of other button.', async () => {
        await stimulusElement1.remove();
        await stimulusElement1.click();

        expect(trackUserAction).toBeCalledTimes(0);
        await stimulusElement2.click();

        expect(trackUserAction).toBeCalledTimes(1);

    });
})
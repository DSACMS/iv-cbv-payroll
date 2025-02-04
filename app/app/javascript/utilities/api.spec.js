import { vi, describe, beforeEach, afterEach, it, expect } from 'vitest'
import * as api from './api'
import * as fetchAPIService from './fetchInternalAPIService'

global.fetch = vi.fn()

function createFetchResponse(data) {
  return { json: () => new Promise((resolve) => resolve(data)) }
}
 // Here we tell Vitest to mock fetch on the `window` object.
describe('trackUserAction', () => {
    beforeEach(async() => {
        // Mock the fetch function.
        const mockResponse = {
            "pinwheel": {
                "event_name": "Event",
                "attributes": {}
            }
        };
        fetch.mockResolvedValue(createFetchResponse(mockResponse))
    })

    it('sends a post request to the user_action endpoint', async () => {
        const data = await api.trackUserAction("Event", {})

        // Check that fetch was called exactly once
        expect(fetch).toHaveBeenCalledTimes(1);
        expect(fetch.mock.calls[0][0]).toBe('/api/pinwheel/user_action')
        expect(fetch.mock.calls[0][1]['method']).toBe('post')
    })

    it('includes CSRV and Content-Type headers', async () => {
        const data = await api.trackUserAction("Event", {})
        expect(fetch).toHaveBeenCalledTimes(1);
        expect(fetch.mock.calls[0][1]).toHaveProperty('headers')
        expect(fetch.mock.calls[0][1]['headers']).toHaveProperty('X-CSRF-Token')
        expect(fetch.mock.calls[0][1]['headers']).toHaveProperty('Content-Type')
        expect(fetch.mock.calls[0][1]['headers']['Content-Type']).toEqual('application/json')
    })

    it('has expected request body', async() => {
        const data = await api.trackUserAction("Event", {})
        expect(fetch.mock.calls[0][1]['body']).toMatchSnapshot()
    })
    it('has expected response payload', async() => {
        const data = await api.trackUserAction("Event", {})
        expect(data).toMatchSnapshot()
    })
        

    afterEach(() => {
        fetch.mockReset()
    })
})

describe('fetchToken', () => {
    beforeEach(async() => {
        // Mock the fetch function.
        const mockResponse = "token-response" 
        fetch.mockResolvedValue(createFetchResponse(mockResponse))
    })

    it('sends a post request to the pinwheel tokens endpoint', async () => {
        const data = await api.fetchToken("response_type", "id", "en")

        // Check that fetch was called exactly once
        expect(fetch).toHaveBeenCalledTimes(1);
        expect(fetch.mock.calls[0][0]).toBe('/api/pinwheel/tokens')
        expect(fetch.mock.calls[0][1]['method']).toBe('post')
    })

    it('includes CSRV and Content-Type headers', async () => {
        const data = await api.fetchToken("response_type", "id", "en")
        expect(fetch).toHaveBeenCalledTimes(1);
        expect(fetch.mock.calls[0][1]).toHaveProperty('headers')
        expect(fetch.mock.calls[0][1]['headers']).toHaveProperty('X-CSRF-Token')
        expect(fetch.mock.calls[0][1]['headers']).toHaveProperty('Content-Type')
        expect(fetch.mock.calls[0][1]['headers']['Content-Type']).toEqual('application/json')
    })

    it('has expected request body', async() => {
        const data = await api.fetchToken("response_type", "id", "en")
        expect(fetch.mock.calls[0][1]['body']).toMatchSnapshot()
    })
    it('has expected response payload', async() => {
        const data = await api.fetchToken("response_type", "id", "en")
        expect(data).toMatchSnapshot()
    })
        
    afterEach(() => {
        fetch.mockReset()
    })
})

describe('fetchInternalAPIService', () => {
    beforeEach(async() => {
        // Mock the fetch function.
        const mockResponse = "good"
        fetch.mockResolvedValue(createFetchResponse(mockResponse))
    })

    it('sends a get request to the arbitrary endpoint', async () => {
        const response = await fetchAPIService.fetchInternalAPIService('/api/arbitrary', {
            "method": "get",
        })
        // Check that fetch was called exactly once
        expect(fetch).toHaveBeenCalledTimes(1);
        expect(fetch.mock.calls[0][0]).toBe('/api/arbitrary')
        expect(fetch.mock.calls[0][1]['method']).toBe('get')
        expect(response).toBe('good')
    })

    it('includes CSRV and Content-Type headers', async () => {
        const response = await fetchAPIService.fetchInternalAPIService('/api/arbitrary', {
            "method": "get",
        })
        expect(fetch).toHaveBeenCalledTimes(1);
        expect(fetch.mock.calls[0][1]).toHaveProperty('headers')
        expect(fetch.mock.calls[0][1]['headers']).toHaveProperty('X-CSRF-Token')
        expect(fetch.mock.calls[0][1]['headers']).toHaveProperty('Content-Type')
        expect(fetch.mock.calls[0][1]['headers']['Content-Type']).toEqual('application/json')
    })

    it('overrides headers', async() => {
        const response = await fetchAPIService.fetchInternalAPIService('/api/arbitrary', {
            "method": "get",
            "headers": {
                "Content-Type": "application/csv",
                "other": "header"
            }
        })

        expect(fetch).toHaveBeenCalledTimes(1);
        expect(fetch.mock.calls[0][1]).toHaveProperty('headers')
        expect(fetch.mock.calls[0][1]['headers']).toHaveProperty('X-CSRF-Token')
        expect(fetch.mock.calls[0][1]['headers']).toHaveProperty('Content-Type')
        expect(fetch.mock.calls[0][1]['headers']['Content-Type']).toEqual('application/csv')
        expect(fetch.mock.calls[0][1]['headers']).toHaveProperty('other')

    })
        
    afterEach(() => {
        fetch.mockReset()
    })
})
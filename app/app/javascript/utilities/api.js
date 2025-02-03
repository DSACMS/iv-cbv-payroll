import { fetchInternalAPIService } from './fetchInternalAPIService';

export const PINWHEEL_USER_ACTION = '/api/pinwheel/user_action';
export const PINWHEEL_TOKENS_GENERATE = '/api/pinwheel/tokens';

export const trackUserAction = (eventName, attributes, scope="pinwheel") => {
  return fetchInternalAPIService(PINWHEEL_USER_ACTION, {
    method: 'post',
    body: JSON.stringify({ [scope]: { event_name: eventName, attributes } }),
  })
};

export const fetchToken = (response_type, id, locale) => {
  return fetchInternalAPIService(PINWHEEL_TOKENS_GENERATE, {
    method: 'post',
    body: JSON.stringify({ response_type, id, locale }),
  })
};


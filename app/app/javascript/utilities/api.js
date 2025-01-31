import CSRF from './csrf';

export const PINWHEEL_USER_ACTION = '/api/pinwheel/user_action';
export const PINWHEEL_TOKENS_GENERATE = '/api/pinwheel/tokens';

export const trackUserAction = (eventName, attributes, scope="pinwheel") => {
  return _fetchInternalService(PINWHEEL_USER_ACTION, {
    method: 'post',
    body: JSON.stringify({ [scope]: { event_name: eventName, attributes } }),
  })
};

export const fetchToken = (response_type, id, locale) => {
  return _fetchInternalService(PINWHEEL_TOKENS_GENERATE, {
    method: 'post',
    body: JSON.stringify({ response_type, id, locale }),
  })
};

export const _fetchInternalService = (uri, params) => {
  const commonHeaders = {
    'X-CSRF-Token': CSRF.token,
    'Content-Type': 'application/json'
  }

  // append X-CSRF-Token and Content-Type headers to existing headers
  const headers = params.headers ? Object.assign({}, commonHeaders, params.headers) :
    commonHeaders;

  params.headers = headers;

  return fetch(uri, params).then(response => response.json())
}
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
  const defaultHeaders = {
    'X-CSRF-Token': CSRF.token,
    'Content-Type': 'application/json'
  }

  return fetch(uri, _addHeadersToParams(defaultHeaders, params))
    .then(response => response.json())
}

const _addHeadersToParams = (defaultHeaders, params) => {
  const requestedHeaders = params.headers;
  params.headers = requestedHeaders ?
    Object.assign({}, defaultHeaders, requestedHeaders) :
    defaultHeaders;

  return params;
}
import CSRF from './csrf';

export const PINWHEEL_USER_ACTION = '/api/pinwheel/user_action';
export const PINWHEEL_TOKENS_GENERATE = '/api/pinwheel/tokens';

export const trackUserAction = (eventName, attributes, scope="pinwheel") => {
  return fetch(PINWHEEL_USER_ACTION, {
    method: 'post',
    headers: {
      'X-CSRF-Token': CSRF.token,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ [scope]: { event_name: eventName, attributes } }),
  }).then(response => response.json());
};

export const fetchToken = (response_type, id, locale) => {
  return fetch(PINWHEEL_TOKENS_GENERATE, {
    method: 'post',
    headers: {
      'X-CSRF-Token': CSRF.token,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ response_type, id, locale }),
  }).then(response => response.json());
};
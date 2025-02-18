import { fetchInternal } from './fetchInternal';
import CSRF from './csrf';

export const EVENTS_USER_ACTION = '/api/events/user_action';
export const PINWHEEL_TOKENS_GENERATE = '/api/pinwheel/tokens';

export const trackUserAction = async  (eventName, attributes) => {
  return fetch(EVENTS_USER_ACTION, {
    method: 'post',
    headers: {
      'X-CSRF-Token': CSRF.token,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ events: { event_name: eventName, attributes } }),
  }).then(response => response.json());
}


export const fetchToken = (response_type, id, locale) => {
  return fetchInternal(PINWHEEL_TOKENS_GENERATE, {
    method: 'post',
    body: JSON.stringify({ response_type, id, locale }),
  })
};


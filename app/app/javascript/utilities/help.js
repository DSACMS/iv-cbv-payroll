import CSRF from './csrf';

const HELP_USER_ACTION = '/api/events/user_action';

export const trackUserAction = async  (eventName, attributes) => {
  return fetch(HELP_USER_ACTION, {
    method: 'post',
    headers: {
      'X-CSRF-Token': CSRF.token,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ events: { event_name: eventName, attributes } }),
  }).then(response => response.json());
}

import CSRF from './csrf';

const HELP_USER_ACTION = '/api/help/user_action';

export const trackUserAction = async  (event_name, source) => {
  return fetch(HELP_USER_ACTION, {
    method: 'post',
    headers: {
      'X-CSRF-Token': CSRF.token,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ event_name, source }),
  }).then(response => response.json());
}
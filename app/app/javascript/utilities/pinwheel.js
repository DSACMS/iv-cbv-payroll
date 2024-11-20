import loadScript from 'load-script';
import CSRF from './csrf';

const PINWHEEL_TOKENS_GENERATE = '/api/pinwheel/tokens';
const PINWHEEL_USER_ACTION = '/api/pinwheel/user_action';

export function loadPinwheel() {
  return new Promise((resolve, reject) => {
    loadScript('https://cdn.getpinwheel.com/pinwheel-v3.0.js', (err, script) => {
      if (err) {
        reject(err);
      } else {
        resolve(Pinwheel);
      }
    });
  });
}

export function initializePinwheel(Pinwheel, linkToken, callbacks) {
  Pinwheel.open({
    linkToken,
    ...callbacks
  });

  return Pinwheel;
}

export const trackUserAction = (response_type, id, name, locale) => {
  return fetch(PINWHEEL_USER_ACTION, {
    method: 'post',
    headers: {
      'X-CSRF-Token': CSRF.token,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ response_type, id, name, locale }),
  }).then(response => response.json());
}

export const fetchToken = (response_type, id, locale) => {
  return fetch(PINWHEEL_TOKENS_GENERATE, {
    method: 'post',
    headers: {
      'X-CSRF-Token': CSRF.token,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ response_type, id, locale }),
  }).then(response => response.json());
}

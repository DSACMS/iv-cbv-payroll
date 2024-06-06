import loadScript from 'load-script';
import metaContent from "./meta";
import CSRF from './csrf';

const PINWHEEL_TOKENS_GENERATE = '/api/pinwheel/tokens';

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

export const fetchToken = (response_type, id) => {
  return fetch(PINWHEEL_TOKENS_GENERATE, {
    method: 'post',
    headers: {
      'X-CSRF-Token': CSRF.token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ response_type, id }),
  }).then(response => response.json());
}

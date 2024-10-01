import loadScript from 'load-script';
import metaContent from "./meta";
import CSRF from './csrf';

const PINWHEEL_TOKENS_GENERATE = '/api/pinwheel/tokens';
const resolveLanguage = (locale) => {
  const enLanguageHeader = 'en,en-US;q=0.9,es;q=0.8,es-ES;q=0.7,es-MX;q=0.6'
  const esLanguageHeader = 'es,es-ES;q=0.9,es-MX;q=0.8,en-US;q=0.7,en;q=0.6'
  return locale === 'en' ? enLanguageHeader : esLanguageHeader
}

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

export const fetchToken = (response_type, id, locale) => {
  return fetch(PINWHEEL_TOKENS_GENERATE, {
    method: 'post',
    headers: {
      'X-CSRF-Token': CSRF.token,
      'Content-Type': 'application/json',
      'Accept-Language': resolveLanguage(locale),
    },
    body: JSON.stringify({ response_type, id }),
  }).then(response => response.json());
}

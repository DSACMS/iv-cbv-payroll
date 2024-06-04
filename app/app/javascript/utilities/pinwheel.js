import loadScript from 'load-script';
import metaContent from "./meta";
import CSRF from './csrf';

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
  return Pinwheel.open({
    linkToken,
    sandbox: metaContent('pinwheel_sandbox'), // Set to false for production environment.
    ...callbacks
  });
}

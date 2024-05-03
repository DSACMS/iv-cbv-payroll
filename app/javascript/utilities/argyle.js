import loadScript from 'load-script';
import metaContent from "./meta";

const ARGYLE_TOKENS_REFRESH = '/api/argyle/tokens';

export function loadArgyle() {
  return new Promise((resolve, reject) => {
    loadScript('https://plugin.argyle.com/argyle.web.v5.js', (err, script) => {
      if (err) {
        reject(err);
      } else {
        resolve(Argyle);
      }
    });
  });
}

export function initializeArgyle(Argyle, userToken, callbacks) {
  return Argyle.create({
    userToken,
    sandbox: metaContent('argyle_sandbox'), // Set to false for production environment.
    ...callbacks
  });
}

export const updateToken = async updateToken => {
  const response = await fetch(ARGYLE_TOKENS_REFRESH).then(response => response.json());

  updateToken(response.token);
}

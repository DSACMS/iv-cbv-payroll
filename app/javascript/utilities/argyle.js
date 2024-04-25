import loadScript from 'load-script';

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
    sandbox: true, // Set to false for production environment.
    ...callbacks
  });
}

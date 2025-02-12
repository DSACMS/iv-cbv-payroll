import loadScript from 'load-script';


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



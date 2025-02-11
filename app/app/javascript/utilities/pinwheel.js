
export function initializePinwheel(Pinwheel, linkToken, callbacks) {
  Pinwheel.open({
    linkToken,
    ...callbacks
  });

  return Pinwheel;
}



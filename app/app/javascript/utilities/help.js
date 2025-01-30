import CSRF from './csrf';

const HELP_TRACK_URL = "/help"

export const trackHelpModalOpened = (event_name, source) => {
    fetch(HELP_TRACK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": CSRF.token
      },
      body: JSON.stringify({ source, event_name })
    }).then(response => response.json())
  }
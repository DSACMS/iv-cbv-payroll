import { fetchInternal } from "./fetchInternal"
import CSRF from "./csrf"

export const EVENTS_USER_ACTION = "/api/events/user_action"
export const PINWHEEL_TOKENS_GENERATE = "/api/pinwheel/tokens"
const ARGYLE_TOKENS_GENERATE = "/api/argyle/tokens"

export const trackUserAction = async (eventName, attributes = {}) => {
  return fetchInternal(EVENTS_USER_ACTION, {
    method: "post",
    body: JSON.stringify({ events: { event_name: eventName, attributes } }),
  })
}

export const fetchPinwheelToken = (response_type, id, locale) => {
  return fetchInternal(PINWHEEL_TOKENS_GENERATE, {
    method: "post",
    body: JSON.stringify({ response_type, id, locale }),
  })
}

export const fetchArgyleToken = async (itemId) => {
  const response = await fetch(ARGYLE_TOKENS_GENERATE, {
    method: "post",
    headers: {
      "X-CSRF-Token": CSRF.token,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({item_id: itemId})
  })

  if (response.redirected) {
    window.location.href = response.url
    return
  }
  
  return response.json()
}

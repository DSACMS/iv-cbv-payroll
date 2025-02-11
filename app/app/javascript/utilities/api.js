import { fetchInternal } from './fetchInternal';

export const PINWHEEL_USER_ACTION = '/api/pinwheel/user_action';
export const PINWHEEL_TOKENS_GENERATE = '/api/pinwheel/tokens';
export const SYNCHRONIZATIONS_FORM_ENDPOINT = '/en/cbv/synchronizations';

export const trackUserAction = (eventName, attributes, scope="pinwheel") => {
  return fetchInternal(PINWHEEL_USER_ACTION, {
    method: 'post',
    body: JSON.stringify({ [scope]: { event_name: eventName, attributes } }),
  })
};

export const fetchToken = (response_type, id, locale) => {
  return fetchInternal(PINWHEEL_TOKENS_GENERATE, {
    method: 'post',
    body: JSON.stringify({ response_type, id, locale }),
  })
};

export const synchronizeCbvData = (userId) => {
  const formData = new FormData().append('user[account_id]', userId)

  return fetchInternal(SYNCHRONIZATIONS_FORM_ENDPOINT, {
    method: 'post',
    body: formData,
  })
};



import CSRF from './csrf';


export const fetchInternalAPIService = (uri, params) => {
  const defaultHeaders = {
    'X-CSRF-Token': CSRF.token,
    'Content-Type': 'application/json'
  };

  return fetch(uri, _addHeadersToParams(defaultHeaders, params))
    .then(response => response.json());
};
const _addHeadersToParams = (defaultHeaders, params) => {
  const requestedHeaders = params.headers;
  params.headers = requestedHeaders ?
    Object.assign({}, defaultHeaders, requestedHeaders) :
    defaultHeaders;

  return params;
};

import CSRF from './csrf';


export const fetchInternal = (uri, params) => {
  const defaultHeaders = {
    'X-CSRF-Token': CSRF.token,
    'Content-Type': 'application/json'
  };

  return fetch(uri, addHeadersToParams(defaultHeaders, params))
    .then(response => response.json());
};
const addHeadersToParams = (defaultHeaders, params) => {
  const requestedHeaders = params.headers;
  params.headers = requestedHeaders ?
    Object.assign({}, defaultHeaders, requestedHeaders) :
    defaultHeaders;

  return params;
};

/**
 * Utility functions for session management
 */
import { fetchInternalAPIService } from './fetchInternalAPIService';

/**
 * Extends the user's session by making a POST request to the API
 * @returns {Promise<Response>} The fetch response
 */
export const extendSession = async () => {
  const response = await fetchInternalAPIService('/api/extend_session', {
    method: 'POST',
    headers: {
      'Accept': 'application/json'
    },
    credentials: 'same-origin'
  });
  
  if (!response.ok) {
    throw new Error(`Failed to extend session: ${response.status}`);
  }
  
  return response;
}; 
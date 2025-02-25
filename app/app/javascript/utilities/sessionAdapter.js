import { fetchInternalAPIService } from './fetchInternalAPIService';

export const sessionAdapter = {
  /**
   * Extends the current user session
   * @returns {Promise<Response>} The fetch response
   */
  extendSession: async () => {
    console.log('sessionAdapter.extendSession called');
    try {
      console.log('Sending POST request to /api/extend_session');
      
      const response = await fetchInternalAPIService('/api/extend_session', {
        method: 'POST',
        headers: {
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      });
      
      console.log('Response data:', response);
      return response;
    } catch (error) {
      console.error('Error extending session:', error);
      throw error;
    }
  }
}; 
import * as ActionCable from '@rails/actioncable';

/**
 * Extends the user's session by sending a message through ActionCable
 * @param {Object} existingSubscription - The existing ActionCable subscription (optional)
 * @returns {Promise} A promise that resolves when the message is sent
 */
export const extendSession = async (existingSubscription = null) => {
  return new Promise((resolve, reject) => {
    let subscription = existingSubscription;
    
    if (!subscription) {
      // Try to find an existing subscription from the default consumer
      const consumer = ActionCable.getConsumer() || ActionCable.createConsumer();
      subscription = consumer.subscriptions.findAll({
        channel: 'SessionChannel'
      })[0];
    }

    if (subscription) {
      subscription.perform('extend_session');
      resolve();
    }
  });
};

export function endSession(subscription) {
  if (!subscription) {
    return Promise.reject(new Error('No active subscription'))
  }
  
  return subscription.perform('destroy_user_session')
} 
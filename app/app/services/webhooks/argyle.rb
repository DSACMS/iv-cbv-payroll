module Webhooks
  class Argyle
    # Argyle's event outcomes are implied by the event name themselves i.e. accounts.failed (implies error)
    # x.fully_synced (implies success)
    # Define all webhook events we're interested in with their outcomes
    # and corresponding synchronizations page "job"
    SUBSCRIBED_WEBHOOK_EVENTS = {
      "users.fully_synced" => {
        status: :success,
        job: %w[income]
      },
      "identities.added" => {
        status: :success,
        job: %w[identity]
      },
      "paystubs.fully_synced" => {
        status: :success,
        job: %w[paystubs employment]
      },
      "gigs.fully_synced" => {
        status: :success,
        job: %w[gigs] # TODO: [FFS-XXX] update front-end/client to support gigs sync status
      },
      "accounts.connected" => {
        status: :success,
        job: [] # we're not concerned with reporting this to the front-end/client
      }
    }.freeze

    def self.generate_signature_digest(payload, webhook_secret)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), webhook_secret, payload)
    end

    # Verify the signature using the appropriate webhook secret
    def self.verify_signature(signature, payload, webhook_secret)
      expected = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), webhook_secret, payload)
      ActiveSupport::SecurityUtils.secure_compare(signature, expected)
    end

    def self.get_webhook_events
      SUBSCRIBED_WEBHOOK_EVENTS.keys
    end

    def self.get_supported_jobs
      SUBSCRIBED_WEBHOOK_EVENTS.values.map { |event| event[:job] }.flatten.compact.uniq
    end

    def self.get_webhook_event_outcome(event)
      SUBSCRIBED_WEBHOOK_EVENTS[event][:status]
    end

    def self.get_webhook_event_jobs(event)
      SUBSCRIBED_WEBHOOK_EVENTS[event][:job]
    end
  end
end

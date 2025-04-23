module Aggregators::Webhooks
  class Argyle
    # When we receive a webhook from Argyle, we store the `status` for the
    # `job`(s) based on the webhook event name.
    #
    # E.g. "identites.added" indicates success of the identity and income jobs.
    #
    # For webhooks with `type: :partial`, additional logic must be applied to:
    # 1. Register the partially_synced webhooks (potentially multiple times)
    #    for any partial sync status needed for an agency.
    # 2. Determine whether the partially_synced success is sufficient to meet
    #    the agency's data requirements.
    #
    # For webhooks with `type: :include_resource, the webhook subscription will include the
    # { "include_resource": true } config to include the resource in the webhook payload.
    SUBSCRIBED_WEBHOOK_EVENTS = {
      "identities.added" => {
        status: :success,
        type: :non_partial,
        job: %w[identity income]
      },
      "paystubs.partially_synced" => {
        status: :success,
        type: :partial,
        job: %w[paystubs employment]
      },
      "gigs.partially_synced" => {
        status: :success,
        type: :partial,
        job: %w[gigs]
      },

      # We're not concerned with reporting these to the front-end/client.
      "accounts.connected" => {
        status: :success,
        type: :non_partial,
        job: []
      },
      "users.fully_synced" => {
        status: :success,
        type: :non_partial,
        job: %w[]
      },

      # The *.fully_synced events may take a long time to return; so we'll
      # store them for measurement purposes, but not tie any jobs' success to
      # their completion.
      "paystubs.fully_synced" => {
        status: :success,
        type: :non_partial,
        job: []
      },
      "gigs.fully_synced" => {
        status: :success,
        type: :non_partial,
        job: []
      },
      "accounts.updated" => {
        status: :success, # this gets overwritten dynamically on system_error in events_controller
        type: :include_resource,
        job: %w[accounts] # the accounts job is strictly used to pass state on system_error
      }
    }.freeze

    def self.generate_signature_digest(payload, webhook_secret)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), webhook_secret, payload)
    end

    # Verify the signature using the appropriate webhook secret
    # See: https://docs.argyle.com/api-guide/webhooks
    def self.verify_signature(signature, payload, webhook_secret)
      expected = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), webhook_secret, payload)
      ActiveSupport::SecurityUtils.secure_compare(signature, expected)
    end

    def self.get_webhook_events(type: :non_partial)
      SUBSCRIBED_WEBHOOK_EVENTS.filter_map { |event_name, event| event_name if type == :all || event[:type] == type }
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

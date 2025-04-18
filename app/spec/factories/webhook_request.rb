FactoryBot.define do
  factory :webhook_request, class: OpenStruct do
    to_create { |instance| instance } # This prevents FactoryBot from calling save!

    trait :argyle do
      transient do
        argyle_service { ArgyleService.new(:sandbox) }
        argyle_account_id { SecureRandom.uuid }
        argyle_user_id { SecureRandom.uuid }
        event_type { "users.fully_synced" }
        provider { "Amazon A to Z" }
        user { ENV["USER"] }
        webhook_secret { 'test_webhook_secret' }
      end

      after(:build) do |webhook_request, evaluator|
        webhook_request.payload =
          case evaluator.event_type
          when "accounts.connected"
            {
              "event" => evaluator.event_type,
              "name" => evaluator.user,
              "data" => {
                "account" => evaluator.argyle_account_id,
                "user" => evaluator.argyle_user_id
              }
            }
          when "identities.added"
            {
              "event" => evaluator.event_type,
              "name" => evaluator.user,
              "data" => {
                "account" => evaluator.argyle_account_id,
                "user" => evaluator.argyle_user_id,
                "identity" => SecureRandom.uuid
              }
            }
          when "users.fully_synced"
            {
              "event" => evaluator.event_type,
              "name" => evaluator.user,
              "data" => {
                "user" => evaluator.argyle_user_id,
                "resource" => {
                  "id" => evaluator.argyle_user_id,
                  "accounts_connected" => [ evaluator.argyle_account_id ],
                  "items_connected" => [ "item_#{SecureRandom.hex(6)}" ],
                  "employers_connected" => [ evaluator.provider ],
                  "external_metadata" => {},
                  "external_id" => evaluator.argyle_user_id,
                  "created_at" => Time.current.iso8601
                }
              }
            }
          when "paystubs.fully_synced"
            {
              "event" => evaluator.event_type,
              "name" => evaluator.user,
              "data" => {
                "account" => evaluator.argyle_account_id,
                "user" => evaluator.argyle_user_id,
                "available_from" => 3.years.ago.iso8601,
                "available_to" => 1.year.from_now.iso8601,
                "available_count" => 153
              }
            }
          when "gigs.fully_synced"
            {
              "event" => evaluator.event_type,
              "name" => evaluator.user,
              "data" => {
                "account" => evaluator.argyle_account_id,
                "user" => evaluator.argyle_user_id,
                "available_from" => 3.years.ago.iso8601,
                "available_to" => 1.year.from_now.iso8601,
                "available_count" => 2503
              }
            }
          end

        # Generate Argyle signature using the service
        webhook_request.headers ||= {}
        webhook_request.headers["x-argyle-signature"] = Aggregators::Webhooks::Argyle.generate_signature_digest(
          webhook_request.payload.to_json,
          evaluator.webhook_secret
        )
      end
    end
  end
end

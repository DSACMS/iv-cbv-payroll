FactoryBot.define do
  factory :webhook_request, class: OpenStruct do
    to_create { |instance| instance } # This prevents FactoryBot from calling save!

    trait :argyle do
      transient do
        event_type { "users.fully_synced" }
        cbv_flow { create(:cbv_flow) }
        account_id { SecureRandom.uuid }
        provider { "Amazon A to Z" }
        argyle_service { ArgyleService.new(:sandbox) }
      end

      after(:build) do |webhook_request, evaluator|
        webhook_request.payload = case evaluator.event_type
        when "users.fully_synced"
          {
            "event" => evaluator.event_type,
            "name" => "test_webhook",
            "data" => {
              "user" => evaluator.cbv_flow.end_user_id,
              "resource" => {
                "id" => evaluator.cbv_flow.end_user_id,
                "accounts_connected" => [evaluator.account_id],
                "items_connected" => ["item_#{SecureRandom.hex(6)}"],
                "employers_connected" => [evaluator.provider],
                "external_metadata" => {},
                "external_id" => evaluator.cbv_flow.end_user_id,
                "created_at" => Time.current.iso8601
              }
            }
          }
        when "accounts.connected"
          {
            "event" => evaluator.event_type,
            "name" => "test_webhook",
            "data" => {
              "user" => evaluator.cbv_flow.end_user_id,
              "resource" => {
                "id" => evaluator.account_id,
                "connection" => {
                  "status" => "connected"
                },
                "providers_connected" => [evaluator.provider]
              }
            }
          } end

        # Generate Argyle signature using the service
        webhook_request.headers ||= {}
        webhook_request.headers["x-argyle-signature"] = evaluator.argyle_service.generate_signature_digest(
          webhook_request.payload.to_json
        )
      end
    end
  end
end

require 'rails_helper'

RSpec.describe ArgyleWebhooksManager, type: :service do
  include ArgyleApiHelper

  let(:ngrok_url) { 'https://ngrok-url.com' }
  let(:webhook_name) { 'test_webhook' }
  let(:test_logger) { Logger.new(StringIO.new) }
  let(:all_webhook_subscriptions) do
    argyle_load_relative_json_file('', 'response_get_webhook_subscriptions.json')['results']
  end
  let(:existing_subscriptions) do
    all_webhook_subscriptions.find_all { |subscription| subscription["name"] == webhook_name }
  end
  let(:argyle_service) { instance_double(Aggregators::Sdk::ArgyleService) }
  let(:argyle_webhooks_manager) do
    # Allow the test to use our mocked ArgyleService
    allow(Aggregators::Sdk::ArgyleService).to receive(:new).and_return(argyle_service)
    described_class.new(logger: test_logger)
  end
  let(:create_webhook_subscription_response) { argyle_load_relative_json_file('', 'response_create_webhook_subscription.json') }
  # Define sandbox_config as a let variable for easier access in tests
  let(:sandbox_config) { double("SandboxConfig", argyle_environment: "sandbox") }
  # Define the webhook events
  let(:non_partial_webhook_events) { Aggregators::Webhooks::Argyle.get_webhook_events(type: :non_partial) }
  let(:partial_webhook_events) { Aggregators::Webhooks::Argyle.get_webhook_events(type: :partial) }
  let(:include_resource_webhook_events) { Aggregators::Webhooks::Argyle.get_webhook_events(type: :include_resource) }

  before do
    # use our stubbed data for the response
    stub_create_webhook_subscription_response
    stub_get_webhook_subscriptions_response
    stub_delete_webhook

    # Allow the ArgyleService instance to receive these methods
    allow(argyle_service).to receive(:create_webhook_subscription).and_return(create_webhook_subscription_response)
    allow(argyle_service).to receive(:get_webhook_subscriptions).and_return({ "results" => existing_subscriptions })
    allow(argyle_service).to receive(:delete_webhook_subscription)

    # This ensures the puts message will have a consistent environment name
    argyle_webhooks_manager.instance_variable_set(:@sandbox_config, double(argyle_environment: "sandbox"))

    # Add stub for ARGYLE_WEBHOOK_SECRET_SANDBOX environment variable
    stub_const('ENV', ENV.to_hash.merge('ARGYLE_WEBHOOK_SECRET_SANDBOX' => 'fake_secret'))
  end

  describe '#existing_subscriptions_with_name' do
    it 'returns the existing subscriptions matching the [name] property' do
      expect(all_webhook_subscriptions.count).to eq(6)
      # out of 6, we only have a single webhook subscription matching "webhook_name"
      expect(argyle_webhooks_manager.existing_subscriptions_with_name(webhook_name)).to eq(existing_subscriptions)
      expect(argyle_webhooks_manager.existing_subscriptions_with_name(webhook_name).count).to eq(1)
    end
  end

  describe '#remove_subscriptions' do
    it "removes an existing user's subscriptions" do
      expect(argyle_service).to receive(:delete_webhook_subscription).with(existing_subscriptions.first["id"])

      # After deletion, the get_webhook_subscriptions should return empty results for this name
      allow(argyle_service).to receive(:get_webhook_subscriptions).and_return({
        "results" => existing_subscriptions.reject { |subscription| subscription["name"] == webhook_name }
      })

      argyle_webhooks_manager.remove_subscriptions(existing_subscriptions)

      updated_subscriptions = argyle_webhooks_manager.existing_subscriptions_with_name(webhook_name)
      expect(updated_subscriptions.count).to eq(0)
    end
  end

  describe '#create_subscriptions_if_necessary' do
    context 'when the subscription does not exist' do
      it 'creates a new subscription when there is no matching subscription' do
        receiver_url = URI.join(ngrok_url, "/webhooks/argyle/events").to_s

        # Make sure URL doesn't match to trigger the "else" branch
        existing_sub = existing_subscriptions.first.merge(
          'url' => "https://different-url.ngrok.io/webhooks/argyle/events",
          'events' => [ "different_events" ]
        )

        allow(argyle_webhooks_manager).to receive(:existing_subscriptions_with_name)
          .and_return([])
        allow(argyle_webhooks_manager).to receive(:existing_subscriptions_with_name)
          .with(webhook_name)
          .and_return([ existing_sub ])

        expect(argyle_service).to receive(:delete_webhook_subscription).with(
          existing_sub["id"]
        )

        expect(test_logger).to receive(:info).with("  Removing existing Argyle webhook subscription (url = https://different-url.ngrok.io/webhooks/argyle/events)")
        expect(test_logger).to receive(:info).with("  Registering Argyle webhooks for Ngrok tunnel in Argyle sandbox...").exactly(4).times
        expect(test_logger).to receive(:info).with("  ✅ Set up Argyle webhook: #{create_webhook_subscription_response["id"]}").exactly(4).times
        expect(test_logger).to receive(:info).with(" Argyle webhook url: #{receiver_url}").exactly(4).times

        expect(argyle_service).to receive(:create_webhook_subscription).with(
          non_partial_webhook_events,
          receiver_url,
          webhook_name,
          nil
        ).and_return(create_webhook_subscription_response)

        expect(argyle_service).to receive(:create_webhook_subscription).with(
          partial_webhook_events,
          receiver_url,
          webhook_name + "-partial",
          { days_synced: 90 }
        ).and_return(create_webhook_subscription_response)

        expect(argyle_service).to receive(:create_webhook_subscription).with(
          include_resource_webhook_events,
          receiver_url,
          webhook_name + "-include-resource",
          { include_resource: true }
        ).and_return(create_webhook_subscription_response)


        result = argyle_webhooks_manager.create_subscriptions_if_necessary(ngrok_url, webhook_name)
        expect(result).to include(create_webhook_subscription_response["id"])
      end

      it 'reuses an existing subscription and removes others with same name' do
        receiver_url = URI.join(ngrok_url, "/webhooks/argyle/events").to_s

        matching_sub = {
          "id" => "matching-subscription-id",
          "name" => webhook_name,
          "url" => receiver_url,
          "events" => non_partial_webhook_events
        }

        other_sub = {
          "id" => "other-subscription-id",
          "name" => webhook_name,
          "url" => "https://old-url.ngrok.io/webhooks/argyle/events",
          "events" => non_partial_webhook_events
        }

        allow(argyle_webhooks_manager).to receive(:existing_subscriptions_with_name)
          .and_return([])
        allow(argyle_webhooks_manager).to receive(:existing_subscriptions_with_name)
          .with(webhook_name)
          .and_return([ matching_sub, other_sub ])

        expect(test_logger).to receive(:info).with("  Existing Argyle webhook subscription found in Argyle sandbox: #{receiver_url}")
        expect(argyle_webhooks_manager).to receive(:remove_subscriptions).with([ other_sub ]).and_call_original # non-partial
        expect(argyle_webhooks_manager).to receive(:remove_subscriptions).with([]).and_call_original.exactly(3).times # no subscriptions for partial and include-resource webhooks
        expect(test_logger).to receive(:info).with("  Registering Argyle webhooks for Ngrok tunnel in Argyle sandbox...").exactly(3).times
        expect(test_logger).to receive(:info).with("  Removing existing Argyle webhook subscription (url = #{other_sub["url"]})")
        expect(test_logger).to receive(:info).with("  ✅ Set up Argyle webhook: #{create_webhook_subscription_response["id"]}").exactly(3).times
        expect(test_logger).to receive(:info).with(" Argyle webhook url: #{receiver_url}").exactly(3).times
        expect(argyle_service).to receive(:delete_webhook_subscription).with(other_sub["id"])
        # Should NOT create a new subscription since we're reusing existing
        expect(argyle_service).not_to receive(:create_webhook_subscription).with(array_including("paystubs.fully_synced"), anything, anything, anything)
        # But it will create a subscription for the partially synced webhooks, since we didn't set it up earlier in the test
        expect(argyle_service).to receive(:create_webhook_subscription).with(array_including("paystubs.partially_synced"), anything, anything, anything)
        expect(argyle_service).to receive(:create_webhook_subscription).with(array_including("paystubs.partially_synced"), anything, anything, anything)
        expect(argyle_service).to receive(:create_webhook_subscription).with(array_including("accounts.updated"), anything, anything, anything)

        argyle_webhooks_manager.create_subscriptions_if_necessary(ngrok_url, webhook_name)
      end
    end
  end
end

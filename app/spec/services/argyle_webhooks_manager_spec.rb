require 'rails_helper'

RSpec.describe ArgyleWebhooksManager, type: :service do
  include ArgyleApiHelper

  let(:ngrok_url) { 'https://ngrok-url.com' }
  let(:webhook_name) { subject.format_identifier_hash('test_webhook') }
  let!(:existing_subscriptions) { read_webhooks_fixture['results'].find_all { |subscription| subscription["name"] == webhook_name } }
  let(:argyle_service) { instance_double(ArgyleService) }
  let(:argyle_webhooks_manager) do
    # Allow the test to use our mocked ArgyleService
    allow(ArgyleService).to receive(:new).and_return(argyle_service)
    described_class.new
  end
  let(:create_webhook_subscription_response) { load_relative_json_file('argyle', 'response_create_webhook_subscription.json') }
  # Define sandbox_config as a let variable for easier access in tests
  let(:sandbox_config) { double("SandboxConfig", argyle_environment: "sandbox") }

  before do
    @all_subscriptions = stub_webhook_subscriptions['results']
    # use our stubbed data for the response
    stub_create_webhook_subscription_response
    stub_get_webhook_subscriptions_response
    stub_delete_webhook

    # Allow the ArgyleService instance to receive these methods
    allow(argyle_service).to receive(:create_webhook_subscription).and_return(create_webhook_subscription_response)
    allow(argyle_service).to receive(:get_webhook_subscriptions).and_return({ "results" => @all_subscriptions })
    allow(argyle_service).to receive(:delete_webhook_subscription)


    # This ensures the puts message will have a consistent environment name
    argyle_webhooks_manager.instance_variable_set(:@sandbox_config, double(argyle_environment: "sandbox"))

    # Add stub for ARGYLE_WEBHOOK_SECRET_SANDBOX environment variable
    stub_const('ENV', ENV.to_hash.merge('ARGYLE_WEBHOOK_SECRET_SANDBOX' => 'fake_secret'))
  end

  describe '#existing_subscriptions_with_name' do
    it 'returns the existing subscriptions matching the [name] property' do
      expect(@all_subscriptions.count).to eq(6)
      # out of 6, we only have a single webhook subscription matching "webhook_name"
      expect(argyle_webhooks_manager.existing_subscriptions_with_name(webhook_name)).to eq(existing_subscriptions)
      expect(argyle_webhooks_manager.existing_subscriptions_with_name(webhook_name).count).to eq(1)
    end
  end

  describe '#remove_subscriptions' do
    it "removes an existing user's subscriptions" do
      # Set up expectations for delete call
      expect(argyle_service).to receive(:delete_webhook_subscription).with(existing_subscriptions.first["id"])

      # After deletion, the get_webhook_subscriptions should return empty results for this name
      allow(argyle_service).to receive(:get_webhook_subscriptions).and_return({
        "results" => @all_subscriptions.reject { |subscription| subscription["name"] == webhook_name }
      })

      argyle_webhooks_manager.remove_subscriptions(existing_subscriptions)

      updated_subscriptions = argyle_webhooks_manager.existing_subscriptions_with_name(webhook_name)
      expect(updated_subscriptions.count).to eq(0)
    end
  end

  describe '#create_subscription_if_necessary' do
    context 'when the subscription does not exist' do
      it 'creates a subscription if it does not exist' do
        receiver_url = URI.join(ngrok_url, "/webhooks/argyle/events").to_s

        # For this test, we want to mimic a case where there's an existing subscription
        # that needs to be removed, then a new one created
        existing_sub = existing_subscriptions.first.merge('events' => [ "different_events" ])

        # Simulate we have an existing subscription but with different config
        allow(argyle_webhooks_manager).to receive(:existing_subscriptions_with_name)
          .with(webhook_name)
          .and_return([ existing_sub ])

        # Expect delete call to be made for existing subscription
        expect(argyle_service).to receive(:delete_webhook_subscription).with(existing_sub["id"])

        expect(argyle_service).to receive(:create_webhook_subscription).with(
          ArgyleWebhooksManager::WEBHOOK_EVENTS,
          receiver_url,
          webhook_name
        ).and_return(create_webhook_subscription_response)

        # First expect the removal message from the existing subscription
        expect(STDOUT).to receive(:puts).with("  Removing existing Argyle webhook subscription (url = #{existing_sub["url"]})")
        expect(STDOUT).to receive(:puts).with("  Registering Argyle webhooks for Ngrok tunnel in Argyle sandbox...")
        expect(STDOUT).to receive(:puts).with("  ✅ Set up Argyle webhook: #{create_webhook_subscription_response["id"]}")

        argyle_webhooks_manager.create_subscription_if_necessary(ngrok_url, webhook_name)
      end

      it 'removes existing subscriptions and creates a new one' do
        receiver_url = URI.join(ngrok_url, "/webhooks/argyle/events").to_s

        # For this test, use a different URL to clearly distinguish it
        existing_sub = existing_subscriptions.first.merge('url' => "https://old-url.ngrok.io/webhooks/argyle/events")

        # Simulate we have an existing subscription with a different URL
        allow(argyle_webhooks_manager).to receive(:existing_subscriptions_with_name)
          .with(webhook_name)
          .and_return([ existing_sub ])

        # Expect delete call to be made for existing subscription
        expect(argyle_service).to receive(:delete_webhook_subscription).with(existing_sub["id"])

        expect(argyle_service).to receive(:create_webhook_subscription).with(
          ArgyleWebhooksManager::WEBHOOK_EVENTS,
          receiver_url,
          webhook_name
        ).and_return(create_webhook_subscription_response)

        expect(STDOUT).to receive(:puts).with("  Removing existing Argyle webhook subscription (url = #{existing_sub["url"]})")
        expect(STDOUT).to receive(:puts).with("  Registering Argyle webhooks for Ngrok tunnel in Argyle sandbox...")
        expect(STDOUT).to receive(:puts).with("  ✅ Set up Argyle webhook: #{create_webhook_subscription_response["id"]}")

        argyle_webhooks_manager.create_subscription_if_necessary(ngrok_url, webhook_name)
      end
    end
  end
end

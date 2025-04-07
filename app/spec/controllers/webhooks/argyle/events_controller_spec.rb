require 'rails_helper'

RSpec.describe Webhooks::Argyle::EventsController, type: :controller do
  let(:argyle_webhook) { class_double('Aggregators::Webhooks::Argyle') }

  # In a runtime scenario- the web client would send a POST request to /api/argyle/tokens
  # This does several things:
  #
  # @link /app/app/controllers/api/argyle_controller.rb
  #
  # 1. Retrieves the CbvFlow from the session
  # 2. Creates an Argyle user which returns an Argyle user "id" and "user_token"
  # 3. Updates the CbvFlow with the Argyle user "id" and "user_token"
  # 4. Returns the "user_token" to the web client which can
  #    be used to create an Argyle "Link" or open the Argyle modal
  before do
    allow(controller).to receive(:authorize_webhook).and_return(true)
    allow(controller).to receive(:event_logger).and_return(double(track: true))
    allow(argyle_webhook).to receive(:verify_signature).and_return(true)
    allow(argyle_webhook).to receive(:get_webhook_event_jobs).and_return([])
    allow(argyle_webhook).to receive(:get_webhook_event_outcome).and_return(:success)
    allow(argyle_webhook).to receive(:get_supported_jobs).and_return(Webhooks::Argyle.get_supported_jobs)
    allow(argyle_webhook).to receive(:get_webhook_events).and_return(Webhooks::Argyle.get_webhook_events)
  end

  shared_examples_for "a webhook that creates a webhook event record" do |event_type, check_status = true|
    let(:webhook_request) { create(:webhook_request, event_type: event_type).payload }

    it "creates a new webhook event with #{event_type}" do
      post :create, params: webhook_request
      expect(response).to have_http_status(:ok) if check_status
    end
  end

  shared_examples_for "a sequential webhook step" do |event_type|
    it "processes the #{event_type} webhook" do
      webhook_request = create(
        :webhook_request,
        :argyle,
        argyle_user_id: cbv_flow.argyle_user_id,
        argyle_account_id: argyle_account_id,
        event_type: event_type
      ).payload

      post :create, params: webhook_request

      payroll_account = PayrollAccount.first
      webhook_event = payroll_account.webhook_events.last

      expect(webhook_event.event_name).to eq(event_type)
      expect(webhook_event.payroll_account.pinwheel_account_id).to eq(payroll_account.pinwheel_account_id)
    end
  end

  describe 'POST #create' do
    context 'with accounts.connected webhook' do
      it_behaves_like "a webhook that creates a webhook event record", "accounts.connected", true
    end

    context 'with identities.added webhook' do
      it_behaves_like "a webhook that creates a webhook event record", "identities.added", false
    end

    context 'with gigs.fully_synced webhook' do
      it_behaves_like "a webhook that creates a webhook event record", "gigs.fully_synced", false
    end

    context 'with users.fully_synced webhook' do
      it_behaves_like "a webhook that creates a webhook event record", "users.fully_synced", false
    end

    context 'with paystubs.fully_synced webhook' do
      it_behaves_like "a webhook that creates a webhook event record", "paystubs.fully_synced", false
    end
  end

  describe 'Argyle webhooks' do
    let(:cbv_flow) { create(:cbv_flow, argyle_user_id: "abc-def-ghi") }
    let(:argyle_account_id) { 'argyle_account_id' }

    # Instead of using "shared_examples_for" we're relying on a test helper method
    # since we cannot use "shared_examples_for" within the "it" test scope
    def process_webhook(event_type)
      webhook_request = create(
        :webhook_request,
        :argyle,
        argyle_user_id: cbv_flow.argyle_user_id,
        argyle_account_id: argyle_account_id,
        event_type: event_type
      ).payload

      post :create, params: webhook_request

      payroll_account = PayrollAccount.last
      webhook_event = payroll_account.webhook_events.last

      expect(webhook_event.event_name).to eq(event_type)
      expect(webhook_event.payroll_account.pinwheel_account_id).to eq(payroll_account.pinwheel_account_id)
    end

    context 'PayrollAccount::Argyle model flow' do
      it 'sequentially tests account synchronization flow' do
        expect(PayrollAccount.count).to eq(0)

        # Test each webhook in sequence
        process_webhook("accounts.connected")
        expect(PayrollAccount.count).to eq(1)

        payroll_account = PayrollAccount.last

        process_webhook("identities.added")
        expect(payroll_account.webhook_events.count).to eq(2)

        process_webhook("users.fully_synced")
        expect(payroll_account.webhook_events.count).to eq(3)

        process_webhook("gigs.fully_synced")
        expect(payroll_account.webhook_events.count).to eq(4)

        process_webhook("paystubs.fully_synced")
        expect(payroll_account.webhook_events.count).to eq(5)

        # expect the PayrollAccount to be fully synced
        expect(payroll_account.has_fully_synced?).to be_truthy
      end
    end
  end
end

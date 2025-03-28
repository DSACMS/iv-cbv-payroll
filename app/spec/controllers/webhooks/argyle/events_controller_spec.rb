require 'rails_helper'

RSpec.describe Webhooks::Argyle::EventsController, type: :controller do
  include ArgyleApiHelper

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
    allow(argyle_webhook).to receive(:get_supported_jobs).and_return(Aggregators::Webhooks::Argyle.get_supported_jobs)
    allow(argyle_webhook).to receive(:get_webhook_events).and_return(Aggregators::Webhooks::Argyle.get_webhook_events)
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
      let(:fake_event_logger) { instance_double(GenericEventTracker) }

      before do
        argyle_stub_request_identities_response('bob')
        argyle_stub_request_paystubs_response('bob')
        allow(controller).to receive(:event_logger).and_return(fake_event_logger)
        allow(fake_event_logger).to receive(:track)
      end

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

      it 'tracks an ApplicantFinishedArgyleSync event' do
        process_webhook("accounts.connected")
        process_webhook("identities.added")
        process_webhook("users.fully_synced")
        process_webhook("gigs.fully_synced")

        expect(fake_event_logger).to receive(:track) do |event_name, _request, attributes|
          expect(event_name).to eq("ApplicantFinishedArgyleSync")
          expect(attributes).to include(
            cbv_flow_id: cbv_flow.id,
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            sync_duration_seconds: be_a(Numeric),

            # Identity fields
            identity_success: true,
            identity_supported: true,
            identity_count: 1,
            identity_full_name_present: true,
            identity_full_name_length: 9,
            identity_date_of_birth_present: true,
            identity_ssn_present: true,
            identity_emails_count: 1,
            identity_phone_numbers_count: 1,

            # Income fields
            income_success: true,
            income_supported: true,
            income_compensation_amount_present: false,
            income_compensation_unit_present: false,
            income_pay_frequency_present: false,

            # Paystubs fields
            paystubs_success: true,
            paystubs_supported: true,
            paystubs_count: 10,
            paystubs_deductions_count: 0,
            paystubs_hours_by_earning_category_count: 0,
            paystubs_hours_present: false,

            # Employment fields
            employment_success: true,
            employment_supported: true,
            employment_status: "employed",
            employment_employer_name: "Lyft Driver",
            employment_employer_address_present: nil,
            employment_employer_phone_number_present: true,
            employment_start_date: "2022-04-07",
            employment_termination_date: nil,

            # Gigs fields
            gigs_success: true,
            gigs_supported: true
          )
        end

        process_webhook("paystubs.fully_synced")
      end
    end
  end
end

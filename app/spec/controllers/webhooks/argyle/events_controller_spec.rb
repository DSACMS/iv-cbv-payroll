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

  shared_examples_for "receiving a webhook" do |event_type|
    let(:webhook_request) do
      create(
        :webhook_request,
        :argyle,
        event_type: event_type,
        argyle_user_id: cbv_flow.argyle_user_id
      )
    end

    it "creates a WebhookEvent with #{event_type}" do
      expect { post :create, params: webhook_request.payload }
        .to change(WebhookEvent, :count).by(1)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #create' do
    let!(:cbv_flow) { create(:cbv_flow, argyle_user_id: "abc-def-ghi") }

    context 'with accounts.connected webhook' do
      it_behaves_like "receiving a webhook", "accounts.connected"
    end

    context 'with identities.added webhook' do
      it_behaves_like "receiving a webhook", "identities.added"
    end

    context 'with gigs.fully_synced webhook' do
      it_behaves_like "receiving a webhook", "gigs.fully_synced"
    end

    context 'with users.fully_synced webhook' do
      # The users.fully_synced webhook is the only one that requires the
      # payroll account to already have been created by a previous webhook.
      before do
        create(
          :payroll_account,
          :argyle,
          cbv_flow: cbv_flow,
          pinwheel_account_id: webhook_request.argyle_account_id,
        )
      end

      it_behaves_like "receiving a webhook", "users.fully_synced"
    end

    context 'with paystubs.fully_synced webhook' do
      it_behaves_like "receiving a webhook", "paystubs.fully_synced"
    end
  end

  describe 'when receiving webhooks for a full Argyle sync' do
    let(:cbv_flow) { create(:cbv_flow, argyle_user_id: "abc-def-ghi") }
    let(:argyle_account_id) { 'argyle_account_id' }
    let(:fake_event_logger) { instance_double(GenericEventTracker) }

    # Instead of using "shared_examples_for" we're relying on a test helper method
    # since we cannot use "shared_examples_for" within the "it" test scope
    def process_webhook(event_type, variant: :connecting)
      webhook_request = create(
        :webhook_request,
        :argyle,
        argyle_user_id: cbv_flow.argyle_user_id,
        argyle_account_id: argyle_account_id,
        event_type: event_type,
        variant: variant
      ).payload

      post :create, params: webhook_request

      payroll_account = PayrollAccount.last
      webhook_event = payroll_account.webhook_events.last

      expect(webhook_event.event_name).to eq(event_type)
      expect(webhook_event.payroll_account.pinwheel_account_id).to eq(payroll_account.pinwheel_account_id)
    end

    around do |ex|
      # The report metric, "paystubs_days_since_last_pay_date" will use Timecop
      # for a static date to reference as "now".
      # This prevents date drifting where test results may vary over time
      Timecop.freeze(Time.local(2025, 5, 15), &ex)
    end

    before do
      allow_any_instance_of(Aggregators::Sdk::ArgyleService)
        .to receive(:fetch_identities_api)
        .and_return(argyle_load_relative_json_file("sarah", "request_identity.json"))
      allow_any_instance_of(Aggregators::Sdk::ArgyleService)
        .to receive(:fetch_paystubs_api)
        .and_return(argyle_load_relative_json_file("sarah", "request_paystubs.json"))
      allow_any_instance_of(Aggregators::Sdk::ArgyleService)
        .to receive(:fetch_gigs_api)
        .and_return(argyle_load_relative_json_file("bob", "request_gigs.json"))
      allow(controller).to receive(:event_logger).and_return(fake_event_logger)
      allow(fake_event_logger).to receive(:track)
    end

    it "results in a fully synced payroll account" do
      # Test each webhook in sequence
      expect do
        process_webhook("accounts.connected")
      end.to change(PayrollAccount, :count).by(1)

      payroll_account = PayrollAccount.last
      expect(payroll_account.sync_in_progress?).to eq(true)

      process_webhook("identities.added")
      expect(payroll_account.webhook_events.count).to eq(2)

      process_webhook("users.fully_synced")
      expect(payroll_account.webhook_events.count).to eq(3)

      process_webhook("gigs.partially_synced")
      expect(payroll_account.webhook_events.count).to eq(4)

      process_webhook("paystubs.partially_synced")
      expect(payroll_account.webhook_events.count).to eq(5)

      # expect the PayrollAccount to be fully synced
      expect(payroll_account.has_fully_synced?).to be_truthy
      expect(payroll_account.reload.sync_succeeded?).to eq(true)
    end

    it "is fully synced even without the *.partially_synced events" do
      process_webhook("accounts.connected")
      process_webhook("identities.added")
      process_webhook("gigs.fully_synced")
      process_webhook("paystubs.fully_synced")
      process_webhook("users.fully_synced")

      payroll_account = PayrollAccount.last
      expect(payroll_account.has_fully_synced?).to eq(true)
      expect(payroll_account.reload.sync_succeeded?).to eq(true)
    end

    it 'tracks an ApplicantFinishedArgyleSync event' do
      process_webhook("accounts.connected")
      process_webhook("identities.added")
      process_webhook("users.fully_synced")
      process_webhook("gigs.partially_synced")

      expect(fake_event_logger).to receive(:track).with("ApplicantReceivedArgyleData", anything, anything)
      expect(fake_event_logger).to receive(:track) do |event_name, _request, attributes|
        expect(event_name).to eq("ApplicantFinishedArgyleSync")
        expect(attributes).to include(
          cbv_flow_id: cbv_flow.id,
          cbv_applicant_id: cbv_flow.cbv_applicant_id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          argyle_environment: "sandbox",
          sync_duration_seconds: be_a(Numeric),

          # Identity fields
          identity_success: true,
          identity_supported: true,
          identity_count: 1,
          identity_full_name_present: true,
          identity_full_name_length: 15,
          identity_date_of_birth_present: true,
          identity_ssn_present: true,
          identity_emails_count: 1,
          identity_phone_numbers_count: 1,

          # Income fields
          income_success: true,
          income_supported: true,
          income_compensation_amount_present: true,
          income_compensation_unit_present: true,
          income_pay_frequency_present: true,
          income_pay_frequency: "biweekly",

          # Paystubs fields
          paystubs_success: true,
          paystubs_supported: true,
          paystubs_count: 10,
          paystubs_deductions_count: 16,
          paystubs_hours_average: 64.848,
          paystubs_hours_by_earning_category_count: 10,
          paystubs_hours_max: 83.04,
          paystubs_hours_median: 66.11,
          paystubs_hours_min: 51.87,
          paystubs_hours_present: true,
          paystubs_earnings_count: 33,
          paystubs_earnings_with_hours_count: 10,
          paystubs_earnings_type_base_count: 10,
          paystubs_earnings_type_bonus_count: 10,
          paystubs_earnings_type_overtime_count: 5,
          paystubs_earnings_type_commission_count: 8,
          paystubs_gross_pay_amounts_max: 192328,
          paystubs_gross_pay_amounts_min: 120139,
          paystubs_gross_pay_amounts_average: 152914.4,
          paystubs_gross_pay_amounts_median: 153103,
          paystubs_days_since_last_pay_date: 73,

          # Employment fields
          employment_success: true,
          employment_supported: true,
          employment_status: "employed",
          employment_type: "w2",
          employment_employer_name: "Whole Foods",
          employment_employer_address_present: true,
          employment_employer_phone_number_present: true,
          employment_start_date: "2022-08-08",
          employment_termination_date: nil,
          employment_type_w2_count: 1,
          employment_type_gig_count: 0,

          # Gigs fields
          gigs_success: true,
          gigs_supported: true,
          gigs_count: 50,
          gigs_duration_present_count: 40,
          gigs_earning_type_adjustment_count: 0,
          gigs_earning_type_incentive_count: 0,
          gigs_earning_type_offer_count: 0,
          gigs_earning_type_other_count: 0,
          gigs_earning_type_work_count: 50,
          gigs_pay_present_count: 50,
          gigs_status_cancelled_count: 10,
          gigs_status_completed_count: 40,
          gigs_status_scheduled_count: 0,
          gigs_type_delivery_count: 0,
          gigs_type_hourly_count: 0,
          gigs_type_rideshare_count: 50,
          gigs_type_services_count: 0
        )
      end

      process_webhook("paystubs.partially_synced")
    end

    it 'tracks an ApplicantReportMetUsefulRequirements event' do
      process_webhook("accounts.connected")
      process_webhook("identities.added")
      process_webhook("users.fully_synced")
      process_webhook("gigs.partially_synced")

      expect(fake_event_logger).to receive(:track).with(
        "ApplicantReportMetUsefulRequirements",
        anything,
        include(
          cbv_flow_id: cbv_flow.id,
          cbv_applicant_id: cbv_flow.cbv_applicant_id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
        )
      ).exactly(1).times

      process_webhook("paystubs.partially_synced")
    end

    context "with multiple partially_synced events" do
      it "tracks only a single ApplicantFinishedArgyleSync event" do
        expect(fake_event_logger).to receive(:track).with("ApplicantFinishedArgyleSync", anything, anything).once
        expect(fake_event_logger).to receive(:track).with("ApplicantReceivedArgyleData", anything, anything)
        process_webhook("accounts.connected")
        process_webhook("identities.added")
        process_webhook("gigs.partially_synced")
        process_webhook("gigs.partially_synced", variant: :six_months)
        process_webhook("paystubs.partially_synced")
        process_webhook("paystubs.partially_synced", variant: :six_months)
        process_webhook("users.fully_synced")
      end

      it "tracks an ApplicantReceivedArgyleData event" do
        process_webhook("accounts.connected")
        process_webhook("identities.added")
        process_webhook("gigs.partially_synced")

        expect(fake_event_logger).to receive(:track) do |event_name, _request, attributes|
          expect(event_name).to eq("ApplicantReceivedArgyleData")
          expect(attributes).to include(
            cbv_flow_id: cbv_flow.id,
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            sync_duration_seconds: be_a(Numeric),
            sync_data: "ninety_days"
          )
        end
        process_webhook("paystubs.partially_synced")

        expect(fake_event_logger).to receive(:track) do |event_name, _request, attributes|
          expect(event_name).to eq("ApplicantReceivedArgyleData")
          expect(attributes).to include(
            cbv_flow_id: cbv_flow.id,
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            sync_data: "six_months",
            sync_duration_seconds: be_a(Numeric),
            sync_event: "paystubs.partially_synced"
          )
        end
        process_webhook("paystubs.partially_synced", variant: :six_months)

        expect(fake_event_logger).to receive(:track) do |event_name, _request, attributes|
          expect(event_name).to eq("ApplicantReceivedArgyleData")
          expect(attributes).to include(
            cbv_flow_id: cbv_flow.id,
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            sync_data: "fully_synced",
            sync_duration_seconds: be_a(Numeric),
            sync_event: "users.fully_synced"
          )
        end
        process_webhook("users.fully_synced")
      end
    end

    it 'results in a sync failure after receiving "system_error" on accounts.updated' do
      expect(PayrollAccount.count).to eq(0)

      process_webhook("accounts.updated", variant: :invalid_mfa)
      process_webhook("accounts.updated", variant: :connecting)
      process_webhook("accounts.connected")
      process_webhook("accounts.updated", variant: :connected)

      expect(PayrollAccount.count).to eq(1)
      payroll_account = PayrollAccount.last

      expect_any_instance_of(PayrollAccount).to receive(:broadcast_replace).twice

      expect(payroll_account.identity_errored_at).to be_nil

      expect(fake_event_logger)
        .to receive(:track)
        .with("ApplicantEncounteredArgyleAccountSystemError", anything, anything).exactly(1).times

      process_webhook("accounts.updated", variant: :system_error)
      payroll_account.reload.webhook_events.reload

      expect(payroll_account.webhook_events.count).to eq(5)
      expect(payroll_account.job_status("accounts")).to equal(:failed)
      expect(payroll_account.sync_failed?).to equal(true)
      expect(payroll_account.has_fully_synced?).to be_falsey
    end
  end
end

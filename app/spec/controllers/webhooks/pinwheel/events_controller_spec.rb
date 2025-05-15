require "rails_helper"

RSpec.describe Webhooks::Pinwheel::EventsController do
  include PinwheelApiHelper

  let(:valid_params) do
    {
      "event" => event_name,
      "payload" => payload
    }
  end
  let(:request_headers) do
    {
      "X-Pinwheel-Signature" => "v2=test-signature",
      "X-Timestamp" => "test-timestamp"
    }
  end
  let(:cbv_flow) { create(:cbv_flow, :invited, client_agency_id: "sandbox") }
  let(:account_id) { "00000000-0000-0000-0000-000000000000" }

  before do
    request.headers.merge!(request_headers)
    allow_any_instance_of(Aggregators::Sdk::PinwheelService).to receive(:generate_signature_digest)
      .with("test-timestamp", anything)
      .and_return("v2=test-signature")
  end

  describe "#create" do
    let(:supported_jobs) { %w[paystubs identity income employment shifts] }

    before do
      pinwheel_stub_request_platform_response
    end

    context "for an 'account.added' event" do
      let(:event_name) { "account.added" }
      let(:payload) do
        {
          "platform_id" => "00000000-0000-0000-0000-000000011111",
          "end_user_id" => cbv_flow.end_user_id,
          "account_id" => account_id,
          "platform_name" => "acme"
        }
      end

      it "creates a PinwheelAccount object and logs events" do
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantCreatedPinwheelAccount", anything, hash_including(
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            platform_name: "acme"
          ))

        expect do
          post :create, params: valid_params
        end.to change(PayrollAccount, :count).by(1)

        pinwheel_account = PayrollAccount.last
        expect(pinwheel_account).to have_attributes(
          cbv_flow_id: cbv_flow.id,
          supported_jobs: include(*supported_jobs),
          pinwheel_account_id: account_id
        )
      end

      context "when the webhook signature is incorrect" do
        before do
          request.headers["X-Pinwheel-Signature"] = "wrong-signature"
        end

        it "discards the webhook" do
          expect do
            post :create, params: valid_params
          end.not_to change(PayrollAccount, :count)

          expect(response).to be_unauthorized
        end
      end
    end

    context "for an 'paystubs.fully_synced' event" do
      let(:event_name) { "paystubs.fully_synced" }
      let(:payload) do
        {
          "account_id" => account_id,
          "end_user_id" => cbv_flow.end_user_id,
          "outcome" => "success"
        }
      end
      let!(:payroll_account) { create(:payroll_account, cbv_flow: cbv_flow, supported_jobs: supported_jobs, pinwheel_account_id: account_id) }

      it "creates a WebhookEvent with outcome=success" do
        post :create, params: valid_params

        expect(payroll_account.webhook_events)
          .to include(have_attributes(event_name: "paystubs.fully_synced", event_outcome: "success"))
        expect(payroll_account.job_succeeded?("paystubs")).to be_truthy
      end

      context "when fully synced" do
        let!(:payroll_account) do
          create(
            :payroll_account,
            :pinwheel_fully_synced,
            cbv_flow: cbv_flow,
            supported_jobs: supported_jobs,
            pinwheel_account_id: account_id,
            created_at: 5.minutes.ago
          )
        end
        let(:event_logger) { instance_double(GenericEventTracker) }

        before do
          pinwheel_stub_request_identity_response
          pinwheel_stub_request_income_metadata_response
          pinwheel_stub_request_end_user_multiple_paystubs_response
          pinwheel_stub_request_employment_info_response
          pinwheel_stub_request_end_user_account_response
          pinwheel_stub_request_platform_response
          pinwheel_stub_request_shifts_response

          allow(controller).to receive(:event_logger).and_return(event_logger)
        end

        it "sends full report analytics when synced" do
          expect(event_logger).to receive(:track).with("ApplicantReportMetUsefulRequirements", anything, anything)
          expect(event_logger).to receive(:track) do |event_name, _request, attributes|
            next unless event_name == "ApplicantFinishedPinwheelSync"

            expect(attributes).to include(
              cbv_flow_id: cbv_flow.id,
              cbv_applicant_id: cbv_flow.cbv_applicant_id,
              invitation_id: cbv_flow.cbv_flow_invitation_id,
              client_agency_id: "sandbox",
              pinwheel_environment: "sandbox",
              sync_duration_seconds: within(1.second).of(5.minutes),

              # Identity fields
              identity_success: true,
              identity_supported: true,
              identity_count: 1,
              identity_full_name_present: true,
              identity_full_name_length: 11,
              identity_date_of_birth_present: true,
              identity_ssn_present: true,
              identity_emails_count: 1,
              identity_phone_numbers_count: 1,
              identity_age_range: "30-39",
              identity_age_range_applicant: "30-39",
              identity_zip_code: "99999",
              identity_account_id: "03e29160-f7e7-4a28-b2d8-813640e030d3",

              # Income fields
              income_success: true,
              income_supported: true,
              income_compensation_amount_present: true,
              income_compensation_unit_present: true,
              income_pay_frequency_present: true,
              income_pay_frequency: "bi-weekly",

              # Paystubs fields
              paystubs_success: true,
              paystubs_supported: true,
              paystubs_count: 2,
              paystubs_deductions_count: 6,
              paystubs_hours_present: true,
              paystubs_hours_average: 80.0,
              paystubs_hours_by_earning_category_count: 2,
              paystubs_hours_max: 80.0,
              paystubs_hours_median: 80.0,
              paystubs_hours_min: 80.0,
              paystubs_earnings_count: 4,
              paystubs_earnings_with_hours_count: 2,
              paystubs_earnings_category_salary_count: 2,
              paystubs_earnings_category_bonus_count: 2,
              paystubs_earnings_category_overtime_count: 0,
              paystubs_gross_pay_amounts_average: 480720.0,
              paystubs_gross_pay_amounts_max: 480720,
              paystubs_gross_pay_amounts_median: 480720,
              paystubs_gross_pay_amounts_min: 480720,

              # Employment fields
              employment_success: true,
              employment_supported: true,
              employment_type: "w2",
              employment_status: "employed",
              employment_account_source: "Testing Payroll Provider Inc.",
              employment_employer_id: "a3e3a4ff-ff5f-4b7c-b347-3e497a729aac",
              employment_employer_name: "Acme Corporation",
              employment_employer_address_present: true,
              employment_employer_phone_number_present: true,
              employment_start_date: "2010-01-01",
              employment_termination_date: nil,
              employment_type_w2_count: 1,
              employment_type_gig_count: 0,

              # Gigs fields
              gigs_success: true,
              gigs_supported: true,
              gigs_count: 3,
              gigs_pay_present_count: 3,
              gigs_start_date_present_count: 3,
              gigs_type_delivery_count: 0,
              gigs_type_other_count: 0,
              gigs_type_rideshare_count: 0,
              gigs_type_shift_count: 3
            )
          end

          post :create, params: valid_params
        end

        it "sends a ApplicantReportMetUsefulRequirements event" do
          expect(event_logger).to receive(:track).with("ApplicantFinishedPinwheelSync", anything, anything)
          expect(event_logger).to receive(:track).with(
            "ApplicantReportMetUsefulRequirements",
            anything,
            include(
              cbv_flow_id: cbv_flow.id,
              cbv_applicant_id: cbv_flow.cbv_applicant_id,
              invitation_id: cbv_flow.cbv_flow_invitation_id,
            )
          )

          post :create, params: valid_params
        end

        context "when not meeting the useful report validations" do
          before do
            pinwheel_stub_request_end_user_no_hours_response
          end

          it "sends a ApplicantReportFailedUsefulRequirements event" do
            expect(event_logger).to receive(:track).with("ApplicantFinishedPinwheelSync", anything, anything)
            expect(event_logger).to receive(:track).with("ApplicantReportFailedUsefulRequirements", anything, anything)

            post :create, params: valid_params
          end
        end
      end
    end

    context "for an 'pending' event outcome" do
      let(:event_name) { "paystubs.fully_synced" }
      let(:payload) do
        {
          "account_id" => account_id,
          "end_user_id" => cbv_flow.end_user_id,
          "outcome" => "pending"
        }
      end
      let!(:payroll_account) { create(:payroll_account, cbv_flow: cbv_flow, supported_jobs: supported_jobs, pinwheel_account_id: account_id) }

      it "creates a WebhookEvent with 'pending' outcome" do
        post :create, params: valid_params

        expect(payroll_account.webhook_events)
          .to include(have_attributes(event_name: "paystubs.fully_synced", event_outcome: "pending"))
        expect(payroll_account.job_succeeded?("paystubs")).to be_falsey
      end
    end
  end
end

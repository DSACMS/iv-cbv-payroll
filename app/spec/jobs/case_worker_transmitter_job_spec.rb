require 'rails_helper'
require 'csv'
require 'active_support/testing/time_helpers'

RSpec.describe CaseWorkerTransmitterJob, type: :job do
  include PinwheelApiHelper
  include ActiveSupport::Testing::TimeHelpers

  include_context "gpg_setup"
  let(:mock_client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }

  let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
  let(:errored_jobs) { [] }
  let(:current_time) { DateTime.parse('2024-06-18 00:00:00') }
  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }
  let(:fake_event_logger) { instance_double(GenericEventTracker, track: nil) }

  let(:cbv_flow) do
    create(:cbv_flow,
           :invited,
           :with_pinwheel_account,
           with_errored_jobs: errored_jobs,
           created_at: current_time - 10.minutes,
           cbv_applicant: cbv_applicant
    )
  end

  around do |ex|
    Timecop.freeze(current_time, &ex)
  end

  let(:transmission_method) {
    raise "define this transmission method in your spec"
  }
  let(:transmission_method_configuration) {
    {}
  }

  let(:mocked_client_id) {
    "sandbox"
  }

  before do
    pinwheel_stub_request_end_user_accounts_response
    pinwheel_stub_request_end_user_paystubs_response
    pinwheel_stub_request_employment_info_response
    pinwheel_stub_request_income_metadata_response
    pinwheel_stub_request_identity_response
    allow(Aggregators::AggregatorReports::PinwheelReport).to receive(:new).and_return(pinwheel_report)

    allow_any_instance_of(described_class).to receive(:current_agency).and_return(mock_client_agency)
    allow(mock_client_agency).to receive(:id).and_return(mocked_client_id)
    allow(mock_client_agency).to receive(:transmission_method).and_return(transmission_method)
    allow(mock_client_agency).to receive(:transmission_method_configuration).and_return(transmission_method_configuration)

    allow_any_instance_of(described_class)
      .to receive(:event_logger)
      .and_return(fake_event_logger)
  end

  context "#transmit_to_caseworker" do
    let(:argyle_report) { build(:argyle_report, :with_argyle_account) }

    before do
      cbv_flow.update(consented_to_authorized_use_at: Time.now)
    end

    context "argyle report" do
      let(:transmission_method) { "shared_email" }
      let(:transmission_method_configuration) { {
        "email" => 'test@example.com'
      } }
      let(:cbv_flow) do
        create(:cbv_flow,
               :invited,
               :with_argyle_account,
               with_errored_jobs: errored_jobs,
               created_at: current_time,
               cbv_applicant: cbv_applicant
        )
      end

      before do
        allow(Aggregators::AggregatorReports::ArgyleReport).to receive(:new).and_return(argyle_report)
        cbv_flow.update(confirmation_code: "SANDBOX456")
      end
    end

    context "when transmission method is shared_email" do
      let(:transmission_method) { "shared_email" }
      let(:transmission_method_configuration) { {
        "email" => 'test@example.com'
      } }

      context "when confirmation_code exists" do
        let(:existing_confirmation_code) { "SANDBOX000" }

        before do
          cbv_flow.update(confirmation_code: existing_confirmation_code)
        end

        it "uses existing confirmation code and generates email" do
          confirmation_code = "SANDBOX123"
          cbv_flow.update(confirmation_code: confirmation_code)

          expect { described_class.new.perform(cbv_flow.id) }.not_to change { cbv_flow.reload.confirmation_code }

          email = ActionMailer::Base.deliveries.last
          expect(email.to).to include('test@example.com')
          expect(email.subject).to include("Income Verification Report")
          expect(email.body.encoded).to include(cbv_flow.cbv_applicant.case_number)
          expect(email.body.encoded).to include(cbv_flow.confirmation_code)
        end

        it "does not override the existing confirmation code" do
          expect { described_class.new.perform(cbv_flow.id) }.not_to change { cbv_flow.reload.confirmation_code }
        end
      end

      it "sends an email to the caseworker and updates transmitted_at" do
        expect {
          described_class.new.perform(cbv_flow.id)
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
                                                           .and change { cbv_flow.reload.transmitted_at }.from(nil)

        email = ActionMailer::Base.deliveries.last
        expect(email.to).to include('test@example.com')
        expect(email.subject).to include("Income Verification Report")
        expect(email.body.encoded).to include(cbv_flow.cbv_applicant.case_number)
      end

      it "tracks an ApplicantSharedIncomeSummary event" do
        described_class.new.perform(cbv_flow.id)

        expect(fake_event_logger).to have_received(:track)
          .with("ApplicantSharedIncomeSummary", anything, include(
            cbv_flow_id: cbv_flow.id,
            flow_started_seconds_ago: 10.minutes.to_i,
          ))
      end
    end

    context "when transmission method is sftp" do
      let(:user) { create(:user, email: "test@test.com") }
      let(:sftp_double) { instance_double(SftpGateway) }
      let(:transmission_method) { "sftp" }
      let(:mocked_client_id) { "az_des" }
      let(:transmission_method_configuration) { {
        "user" => "user",
        "password" => "password",
        "url" => "sftp.com",
        "sftp_directory" => "test"
      } }
      let(:now) { Time.zone.parse('2025-01-01 08:00:30') }

      before do
        allow(SftpGateway).to receive(:new).and_return(sftp_double)
        allow(sftp_double).to receive(:upload_data)

        travel_to now
      end

      it "generates and sends data to SFTP and updates transmitted_at" do
        agency_id_number = cbv_applicant.agency_id_number
        beacon_id = cbv_applicant.beacon_id

        cbv_flow.update!(confirmation_code: "AZDES001", consented_to_authorized_use_at: now, client_agency_id: "ma")
        cbv_flow.cbv_applicant.update!(case_number: "01000", client_agency_id: "ma", beacon_id: beacon_id, agency_id_number: agency_id_number)

        expect(sftp_double).to receive(:upload_data).with(anything, /test\/CBVPilot_00001000_20250101_ConfAZDES001.pdf/)


        expect { described_class.new.perform(cbv_flow.id) }.to change { cbv_flow.reload.transmitted_at }
      end
    end

    context "when transmission method is s3" do
      let(:user) { create(:user, email: "test@test.com") }
      let(:s3_service_double) { instance_double(S3Service) }
      let(:transmission_method) { "s3" }
      let(:mocked_client_id) { "ma" }
      let(:transmission_method_configuration) { {
        "bucket" => "test-bucket",
        "public_key" => @public_key
      } }

      before do
        allow(S3Service).to receive(:new).and_return(s3_service_double)
        allow(s3_service_double).to receive(:upload_file)
      end

      it "generates, gzips, encrypts, and uploads PDF and CSV files to S3" do
        agency_id_number = cbv_applicant.agency_id_number
        beacon_id = cbv_applicant.beacon_id

        expect(s3_service_double).to receive(:upload_file).once do |file_path, file_name|
          expect(file_path).to end_with('.gpg')
          expect(file_name).to start_with("outfiles/IncomeReport_#{cbv_applicant.agency_id_number}_")
          expect(file_name).to end_with('.tar.gz.gpg')
          expect(File.exist?(file_path)).to be true
        end

        expect(CSV).to receive(:generate).and_wrap_original do |original_method, *args, &block|
          csv_content = original_method.call(*args, &block)
          csv_rows = CSV.parse(csv_content, headers: true)
          expect(csv_rows[0]["client_id"]).to eq(agency_id_number)
          csv_content
        end

        cbv_flow.update(client_agency_id: "ma")
        cbv_applicant.update(client_agency_id: "ma")
        cbv_applicant.update(beacon_id: beacon_id)
        cbv_applicant.update(agency_id_number: agency_id_number)

        described_class.new.perform(cbv_flow.id)
      end

      it "handles errors during file processing and upload" do
        cbv_flow.update(client_agency_id: 'ma')
        allow_any_instance_of(GpgEncryptable).to receive(:gpg_encrypt_file).and_raise(StandardError, "Encryption failed")

        expect {
          described_class.new.perform(cbv_flow.id)
        }.to raise_error(StandardError, "Encryption failed")

        expect(s3_service_double).not_to have_received(:upload_file)
        expect(cbv_flow.reload.transmitted_at).to be_nil
      end

      it "tracks an ApplicantSharedIncomeSummary event" do
        described_class.new.perform(cbv_flow.id)

        expect(fake_event_logger).to have_received(:track)
          .with("ApplicantSharedIncomeSummary", anything, include(
            cbv_flow_id: cbv_flow.id
          ))
      end
    end
  end
end

require 'rails_helper'
require 'csv'
RSpec.describe CaseWorkerTransmitterJob, type: :job do
  include PinwheelApiHelper
  include_context "gpg_setup"
  let(:mock_client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }


  let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
  let(:supported_jobs) { %w[income paystubs employment identity] }
  let(:errored_jobs) { [] }
  let(:current_time) { Date.parse('2024-06-18') }
  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }

  let(:cbv_flow) do
    create(:cbv_flow,
           :invited,
           :with_pinwheel_account,
           with_errored_jobs: errored_jobs,
           created_at: current_time,
           supported_jobs: supported_jobs,
           cbv_applicant: cbv_applicant
    )
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
  end

  context "#transmit_to_caseworker" do
    let(:supported_jobs) { %w[income paystubs employment identity] }
    let(:argyle_report) { build(:argyle_report, :with_argyle_account) }

    before do
      cbv_flow.update(consented_to_authorized_use_at: Time.now)
    end

    context "argyle report" do
      let(:transmission_method) { "shared_email" }
      let(:transmission_method_configuration) { {
        "email" => 'test@example.com'
      }}
      let(:cbv_flow) do
        create(:cbv_flow,
               :invited,
               :with_argyle_account,
               with_errored_jobs: errored_jobs,
               created_at: current_time,
               supported_jobs: supported_jobs,
               cbv_applicant: cbv_applicant
        )
      end

      before do
        allow(Aggregators::AggregatorReports::ArgyleReport).to receive(:new).and_return(argyle_report)
      end

      it "generates a new confirmation code and generates email" do
        expect { described_class.new.perform(cbv_flow.id) }.to change { cbv_flow.reload.confirmation_code }.to start_with("SANDBOX")
        email = ActionMailer::Base.deliveries.last
        expect(email.to).to include('test@example.com')
        expect(email.subject).to include("Income Verification Report")
        expect(email.body.encoded).to include(cbv_flow.cbv_applicant.case_number)
      end
    end

    context "when transmission method is shared_email" do
      let(:transmission_method) { "shared_email" }
      let(:transmission_method_configuration) { {
        "email" => 'test@example.com'
      }}

      it "generates a new confirmation code" do
        expect { described_class.new.perform(cbv_flow.id) }.to change { cbv_flow.reload.confirmation_code }.to start_with("SANDBOX")
      end

      it "removes underscores from the agency name" do
        cbv_flow.update!(client_agency_id: "az_des")
        expect { described_class.new.perform(cbv_flow.id) }.to change { cbv_flow.reload.confirmation_code }.to(start_with("AZDES"))
      end

      context "when confirmation_code already exists" do
        let(:existing_confirmation_code) { "SANDBOX000" }

        before do
          cbv_flow.update(confirmation_code: existing_confirmation_code)
        end

        it "does not override the existing confirmation code" do
          expect { described_class.new.perform(cbv_flow.id) }.not_to change { cbv_flow.reload.client_agency_id }
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

      # Note that we are not testing events here because doing so requires use of expect_any_instance_of,
      # which does not play nice since there are multiple instances of the event logger.
    end

    context "when transmission method is s3" do
      let(:user) { create(:user, email: "test@test.com") }
      let(:s3_service_double) { instance_double(S3Service) }
      let(:transmission_method) { "s3" }
      let(:mocked_client_id) { "ma" }
      let(:transmission_method_configuration) { {
        "bucket"     => "test-bucket",
        "public_key" => @public_key
      }}
      # let(:pinwheel_service_double) { instance_double(Aggregators::Sdk::PinwheelService) }
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
    end
  end
end

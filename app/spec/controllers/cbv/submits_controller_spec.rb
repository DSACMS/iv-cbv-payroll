require "rails_helper"

RSpec.describe Cbv::SubmitsController do
  include PinwheelApiHelper
  include_context "gpg_setup"

  attr_reader :test_fixture_directory

  before(:all) do
    @test_fixture_directory = 'pinwheel'
  end

  let(:supported_jobs) { %w[income paystubs employment identity] }
  let(:errored_jobs) { [] }
  let(:current_time) { Date.parse('2024-06-18') }
  let(:employment_errored_at) { nil }
  let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }

  let(:cbv_flow) do
    create(:cbv_flow,
      :with_pinwheel_account,
      with_errored_jobs: errored_jobs,
      created_at: current_time,
      supported_jobs: supported_jobs,
      cbv_applicant: cbv_applicant
    )
  end
  let(:mock_client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }
  let(:nyc_user) { create(:user, email: "test@test.com", client_agency_id: 'nyc') }
  let(:ma_user) { create(:user, email: "test@example.com", client_agency_id: 'ma') }

  before do
    allow(mock_client_agency).to receive(:transmission_method_configuration).and_return({
      "bucket"            => "test-bucket",
      "region"            => "us-west-2",
      "access_key_id"     => "SOME_ACCESS_KEY",
      "secret_access_key" => "SOME_SECRET_ACCESS_KEY",
      "public_key"        => @public_key
    })

    cbv_applicant.update(snap_application_date: current_time)

    cbv_flow.payroll_accounts.first.update(pinwheel_account_id: "03e29160-f7e7-4a28-b2d8-813640e030d3")
  end

  around do |ex|
    Timecop.freeze(&ex)
  end

  describe "#show" do
    before do
      session[:cbv_flow_id] = cbv_flow.id
      allow(Aggregators::AggregatorReports::PinwheelReport).to receive(:new).and_return(pinwheel_report)
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(controller.send(:has_consent)).to be_falsey
        expect(response.body).to include("Legal agreement")
        expect(response).to be_successful
      end

      it "renders pdf properly" do
        get :show, format: :pdf
        expect(response).to be_successful
        expect(response.header['Content-Type']).to include 'pdf'
      end

      context "when only paystubs are supported" do
        let(:supported_jobs) { %w[paystubs] }

        it "renders pdf properly" do
          get :show, format: :pdf
          expect(response).to be_successful
          expect(response.header['Content-Type']).to include 'pdf'
        end
      end

      context "when a supported job errors" do
        let(:supported_jobs) { %w[income paystubs employment] }
        let(:errored_jobs) { [ "employment" ] }

        it "renders pdf properly" do
          get :show, format: :pdf
          expect(response).to be_successful
          expect(response.header['Content-Type']).to include 'pdf'
        end
      end
    end

    context "when legal agreement checked" do
      before do
        cbv_flow.update(consented_to_authorized_use_at: Time.now)
      end

      it "hides legal agreement if already checked" do
        get :show

        expect(response.body).not_to include("Legal Agreement")
      end
    end

    context "for a completed CbvFlow" do
      before do
        cbv_flow.update(confirmation_code: "ABC123")
      end

      it "allows the user to download the PDF summary" do
        get :show, format: :pdf
        expect(response).to be_successful
        expect(response.header['Content-Type']).to include 'pdf'
      end

      it "redirects the user to the success page if the user goes back to the page" do
        get :show
        expect(response).to redirect_to(cbv_flow_success_path)
      end
    end

    it "renders pdf properly" do
      get :show, format: :pdf
      expect(response).to be_successful
      expect(response.header['Content-Type']).to include 'pdf'
    end

    context "when only paystubs are supported" do
      let(:supported_jobs) { %w[paystubs] }

      it "renders pdf properly" do
        get :show, format: :pdf
        expect(response).to be_successful
        expect(response.header['Content-Type']).to include 'pdf'
      end
    end

    context "when a supported job errors" do
      let(:supported_jobs) { %w[income paystubs employment] }
      let(:errored_jobs) { [ "employment" ] }

      it "renders pdf properly" do
        get :show, format: :pdf
        expect(response).to be_successful
        expect(response.header['Content-Type']).to include 'pdf'
      end
    end
  end

  describe "#update" do
    before do
      session[:cbv_flow_id] = cbv_flow.id
      sign_in nyc_user
      allow(Aggregators::AggregatorReports::PinwheelReport).to receive(:new).and_return(pinwheel_report)
    end

    context "without consent" do
      it "redirects back with an alert" do
        patch :update
        expect(response).to redirect_to(cbv_flow_submit_path)
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to eq("Please check the legal agreement box to share your report.")
      end
    end

    context "with consent" do
      it "generates a new confirmation code" do
        expect(cbv_flow.confirmation_code).to be_nil
        patch :update, params: { cbv_flow: { consent_to_authorized_use: "1" } }
        cbv_flow.reload
        expect(cbv_flow.confirmation_code).to start_with("SANDBOX")
      end

      it "removes underscores from the agency name" do
        cbv_flow.update(client_agency_id: "az_des")
        expect(cbv_flow.confirmation_code).to be_nil
        patch :update, params: { cbv_flow: { consent_to_authorized_use: "1" } }
        cbv_flow.reload
        expect(cbv_flow.confirmation_code).to start_with("AZDES")
      end
    end

    context "when confirmation_code already exists" do
      let(:existing_confirmation_code) { "SANDBOX000" }

      before do
        cbv_flow.update(confirmation_code: existing_confirmation_code)
      end

      it "does not override the existing confirmation code" do
        expect(cbv_flow.reload.confirmation_code).to eq(existing_confirmation_code)
        expect { patch :update }.not_to change { cbv_flow.reload.confirmation_code }
      end
    end

    context "when sending an email to the caseworker" do
      before do
        cbv_flow.update(consented_to_authorized_use_at: Time.now)
        sign_in ma_user
        allow(mock_client_agency).to receive(:transmission_method).and_return('s3')
        allow(mock_client_agency).to receive(:id).and_return('ma')
        allow(Aggregators::AggregatorReports::PinwheelReport).to receive(:new).and_return(pinwheel_report)
      end

      it "sends the email" do
        expect do
          patch :update
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq("Income Verification Report ABC1234 has been received")
      end

      it "stores the current time as transmitted_at" do
        expect { patch :update }
          .to change { cbv_flow.reload.transmitted_at }
                .from(nil)
                .to(within(5.second).of(Time.now))
      end

      it "redirects to success screen" do
        patch :update
        expect(response).to redirect_to({ controller: :successes, action: :show })
      end
    end

    context "#transmit_to_caseworker" do
      before do
        cbv_flow.update(consented_to_authorized_use_at: Time.now)

        # Set up the mock_client_agency behavior
        allow(mock_client_agency).to receive(:transmission_method_configuration).and_return({
         "bucket"            => "test-bucket",
         "region"            => "us-west-2",
         "access_key_id"     => "SOME_ACCESS_KEY",
         "secret_access_key" => "SOME_SECRET_ACCESS_KEY",
         "public_key"        => @public_key
         })
      end

      context "when transmission method is shared_email" do
        before do
          sign_in nyc_user
          allow(mock_client_agency).to receive(:transmission_method).and_return('shared_email')
          allow(mock_client_agency).to receive(:transmission_method_configuration).and_return({
             "email" => 'test@example.com'
          })
          allow(controller).to receive(:current_agency).and_return(mock_client_agency)
          allow(Aggregators::AggregatorReports::PinwheelReport).to receive(:new).and_return(pinwheel_report)
        end

        it "sends an email to the caseworker and updates transmitted_at" do
          expect {
            patch :update
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
        # let(:pinwheel_service_double) { instance_double(Aggregators::Sdk::PinwheelService) }
        before do
          sign_in user
          allow(S3Service).to receive(:new).and_return(s3_service_double)
          allow(s3_service_double).to receive(:upload_file)
          allow(mock_client_agency).to receive_messages(
            id: 'ma',
            transmission_method: 's3',
            transmission_method_configuration: {
              "bucket"     => "test-bucket",
              "public_key" => @public_key
            }
          )

          allow(controller).to receive(:current_agency).and_return(mock_client_agency)

          # Stub pinwheel_for method to return our double
          stub_request_end_user_accounts_response
          stub_request_end_user_paystubs_response
          stub_request_employment_info_response
          stub_request_income_metadata_response
          stub_request_identity_response
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

          patch :update
        end

        it "handles errors during file processing and upload" do
          cbv_flow.update(client_agency_id: 'ma')
          allow_any_instance_of(GpgEncryptable).to receive(:gpg_encrypt_file).and_raise(StandardError, "Encryption failed")

          expect {
            patch :update
          }.to raise_error(StandardError, "Encryption failed")

          expect(s3_service_double).not_to have_received(:upload_file)
          expect(cbv_flow.reload.transmitted_at).to be_nil
        end
      end
    end
  end
end

require "rails_helper"

RSpec.describe Cbv::SummariesController do
  include PinwheelApiHelper
  include_context "gpg_setup"

  let(:supported_jobs) { %w[income paystubs employment identity] }
  let(:flow_started_seconds_ago) { 300 }
  let(:employment_errored_at) { nil }
  let(:cbv_flow) { create(:cbv_flow, :with_pinwheel_account, created_at: flow_started_seconds_ago.seconds.ago, case_number: "ABC1234", supported_jobs: supported_jobs, employment_errored_at: employment_errored_at) }
  let(:cbv_flow_invitation) { cbv_flow.cbv_flow_invitation }
  let(:mock_site) { instance_double(SiteConfig::Site) }
  let(:nyc_user) { create(:user, email: "test@test.com", site_id: 'nyc') }
  let(:ma_user) { create(:user, email: "test@example.com", site_id: 'ma') }

  before do
    allow(mock_site).to receive(:transmission_method_configuration).and_return({
      "bucket"            => "test-bucket",
      "region"            => "us-west-2",
      "access_key_id"     => "SOME_ACCESS_KEY",
      "secret_access_key" => "SOME_SECRET_ACCESS_KEY",
      "public_key"        => @public_key
    })

    session[:cbv_flow_invitation] = cbv_flow_invitation
    cbv_flow.pinwheel_accounts.first.update(pinwheel_account_id: "03e29160-f7e7-4a28-b2d8-813640e030d3")
  end

  around do |ex|
    Timecop.freeze(&ex)
  end

  describe "#show" do
    before do
      cbv_flow_invitation.update(snap_application_date: Date.parse('2024-06-18'))
      cbv_flow_invitation.update(created_at: Date.parse('2024-03-20'))
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_end_user_accounts_response
      stub_request_end_user_paystubs_response
      stub_request_employment_info_response unless employment_errored_at
      stub_request_income_metadata_response if supported_jobs.include?("income")
      stub_request_identity_response
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(controller.send(:has_consent)).to be_falsey
        # 90 days before snap_application_date
        start_date = "March 20, 2024"
        # Should be the formatted version of snap_application_date
        end_date = "June 18, 2024"
        expect(assigns[:payments_ending_at]).to eq(end_date)
        expect(assigns[:payments_beginning_at]).to eq(start_date)
        expect(response.body).to include("Legal Agreement")
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
        let(:employment_errored_at) { Time.current.iso8601 }

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
  end

  describe "#update" do
    before do
      session[:cbv_flow_id] = cbv_flow.id
      sign_in nyc_user
      stub_request_end_user_accounts_response
      stub_request_end_user_paystubs_response
      stub_request_employment_info_response
      stub_request_income_metadata_response
      stub_request_identity_response
    end

    context "without consent" do
      it "redirects back with an alert" do
        patch :update
        expect(response).to redirect_to(cbv_flow_summary_path)
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to eq("You must check the legal agreement checkbox to proceed.")
      end
    end

    context "with consent" do
      it "generates a new confirmation code" do
        expect(cbv_flow.confirmation_code).to be_nil
        patch :update, params: { cbv_flow: { consent_to_authorized_use: "1" } }
        cbv_flow.reload
        expect(cbv_flow.confirmation_code).to start_with("SANDBOX")
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
        allow(mock_site).to receive(:transmission_method).and_return('s3')
        allow(mock_site).to receive(:id).and_return('ma')
        stub_request_end_user_accounts_response
        stub_request_end_user_paystubs_response
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
        # Mock the current_site method
        allow_any_instance_of(Cbv::BaseController).to receive(:current_site).and_return(mock_site)

        # Set up the mock_site behavior
        allow(mock_site).to receive(:transmission_method_configuration).and_return({
         "bucket"            => "test-bucket",
         "region"            => "us-west-2",
         "access_key_id"     => "SOME_ACCESS_KEY",
         "secret_access_key" => "SOME_SECRET_ACCESS_KEY",
         "public_key"        => @public_key
         })
      end

      context "when transmission method is shared_email" do
        let(:nyc_user) { create(:user, email: "test@test.com", site_id: 'nyc') }

        before do
          sign_in nyc_user
          allow(mock_site).to receive(:transmission_method).and_return('shared_email')
          allow(mock_site).to receive(:transmission_method_configuration).and_return({
             "email" => 'test@example.com'
          })
        end

        it "sends an email to the caseworker and updates transmitted_at" do
          expect {
            patch :update
          }.to change { ActionMailer::Base.deliveries.count }.by(1)
            .and change { cbv_flow.reload.transmitted_at }.from(nil)

          email = ActionMailer::Base.deliveries.last
          expect(email.to).to include('test@example.com')
          expect(email.subject).to include("Income Verification Report")
          expect(email.body.encoded).to include(cbv_flow.case_number)
        end
      end

      context "when transmission method is s3" do
        let(:user) { create(:user, email: "test@test.com") }
        let(:s3_service_double) { instance_double(S3Service) }
        let(:pinwheel_service_double) { instance_double(PinwheelService) }

        before do
          sign_in user
          allow(S3Service).to receive(:new).and_return(s3_service_double)
          allow(s3_service_double).to receive(:upload_file)
          allow(mock_site).to receive(:id).and_return('ma')
          allow(mock_site).to receive(:transmission_method).and_return('s3')
          allow(NewRelicEventTracker).to receive(:track)

          # Stub pinwheel_for method to return our double
          allow_any_instance_of(ApplicationController).to receive(:pinwheel_for).and_return(pinwheel_service_double)

          # Stub all relevant PinwheelService methods
          allow(pinwheel_service_double).to receive(:fetch_accounts).and_return({ "data" => [ { "id" => "sample_account_id" } ] })
          allow(pinwheel_service_double).to receive(:fetch_paystubs).and_return({ "data" => [] })
          allow(pinwheel_service_double).to receive(:fetch_employment).and_return({ "data" => {} })
          allow(pinwheel_service_double).to receive(:fetch_identity).and_return({ "data" => {} })
          allow(pinwheel_service_double).to receive(:fetch_income_metadata).and_return({ "data" => {} })
        end

        it "generates, gzips, encrypts, and uploads PDF and CSV files to S3" do
          expect(s3_service_double).to receive(:upload_file).once do |file_path, file_name|
            expect(file_path).to end_with('.gpg')
            expect(file_name).to start_with("outfiles/IncomeReport_#{cbv_flow_invitation.agency_id_number}_")
            expect(file_name).to end_with('.tar.gz.gpg')
            expect(File.exist?(file_path)).to be true
          end

          cbv_flow.update(site_id: 'ma')
          cbv_flow_invitation.update(agency_id_number: "1234")
          patch :update

          expect(NewRelicEventTracker).to have_received(:track).with("IncomeSummarySharedWithCaseworker", hash_including(
            timestamp:                                 be_a(Integer),
            site_id:                                   cbv_flow.site_id,
            cbv_flow_id:                               cbv_flow.id,
            account_count:                             be_a(Integer),
            paystub_count:                             be_a(Integer),
            account_count_with_additional_information: be_a(Integer),
            flow_started_seconds_ago:                  be_a(Integer)
          ))
        end

        it "handles errors during file processing and upload" do
          allow(controller).to receive(:gpg_encrypt_file).and_raise(StandardError, "Encryption failed")

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

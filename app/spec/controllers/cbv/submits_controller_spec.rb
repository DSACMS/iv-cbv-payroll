require "rails_helper"

RSpec.describe Cbv::SubmitsController do
  include PinwheelApiHelper
  include_context "gpg_setup"

  let(:supported_jobs) { %w[income paystubs employment identity] }
  let(:errored_jobs) { [] }
  let(:current_time) { Date.parse('2024-06-18') }
  let(:employment_errored_at) { nil }
  let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
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
  let(:mock_client_agency) { instance_double(ClientAgencyConfig::ClientAgency) }
  let(:nyc_user) { create(:user, email: "test@test.com", client_agency_id: 'nyc') }
  let(:ma_user) { create(:user, email: "test@example.com", client_agency_id: 'ma') }

  before do
    allow(mock_client_agency).to receive(:transmission_method_configuration).and_return({
                                                                                          "bucket" => "test-bucket",
                                                                                          "region" => "us-west-2",
                                                                                          "access_key_id" => "SOME_ACCESS_KEY",
                                                                                          "secret_access_key" => "SOME_SECRET_ACCESS_KEY",
                                                                                          "public_key" => @public_key
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
      pinwheel_stub_request_end_user_accounts_response
      pinwheel_stub_request_end_user_paystubs_response
      pinwheel_stub_request_employment_info_response unless errored_jobs.include?("employment")
      pinwheel_stub_request_income_metadata_response if supported_jobs.include?("income")
      pinwheel_stub_request_identity_response
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

        it "bounces to synchronization failures" do
          get :show, format: :pdf
          expect(response).to redirect_to(cbv_flow_synchronization_failures_path)
        end
      end

      context "when multiple accounts, one errored one good" do
        let(:supported_jobs) { %w[income paystubs employment] }
        let(:errored_jobs) { [ "employment" ] }

        it "renders a pdf" do
          create(:payroll_account, :pinwheel_fully_synced, cbv_flow: cbv_flow, pinwheel_account_id: "account1")
          expect(response).to be_successful
          expect(response.header['Content-Type']).to include 'pdf'
        end
      end

      context "when rendering for a caseworker" do
        it "shows the right client information fields" do
          get :show, format: :pdf, params: {
            is_caseworker: "true"
          }

          pdf = PDF::Reader.new(StringIO.new(response.body))
          pdf_text = ""
          pdf.pages.each do |page|
            pdf_text += page.text
          end

          expect(pdf_text).to include(I18n.t("cbv.applicant_informations.sandbox.fields.first_name.prompt"))
          expect(pdf_text).to include(I18n.t("cbv.applicant_informations.sandbox.fields.middle_name.prompt"))
          expect(pdf_text).to include(I18n.t("cbv.applicant_informations.sandbox.fields.last_name.prompt"))
          expect(pdf_text).to include(I18n.t("cbv.applicant_informations.sandbox.fields.case_number.prompt"))
        end
      end

      context "when rendering for a client" do
        it "does not show the client information fields" do
          get :show, format: :pdf

          pdf = PDF::Reader.new(StringIO.new(response.body))
          pdf_text = ""
          pdf.pages.each do |page|
            pdf_text += page.text
          end

          expect(pdf_text).not_to include(I18n.t("cbv.applicant_informations.sandbox.fields.first_name.prompt"))
          expect(pdf_text).not_to include(I18n.t("cbv.applicant_informations.sandbox.fields.middle_name.prompt"))
          expect(pdf_text).not_to include(I18n.t("cbv.applicant_informations.sandbox.fields.last_name.prompt"))
          expect(pdf_text).not_to include(I18n.t("cbv.applicant_informations.sandbox.fields.case_number.prompt"))
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
  end

  describe "#update" do
    before do
      session[:cbv_flow_id] = cbv_flow.id
      sign_in nyc_user
      pinwheel_stub_request_end_user_accounts_response
      pinwheel_stub_request_end_user_paystubs_response
      pinwheel_stub_request_employment_info_response
      pinwheel_stub_request_income_metadata_response
      pinwheel_stub_request_identity_response
      allow(Aggregators::AggregatorReports::PinwheelReport).to receive(:new).and_return(pinwheel_report)
    end

    describe "with activejob enabled" do
      around do |example|
        ClimateControl.modify ACTIVEJOB_ENABLED: 'true' do
          example.run
        end
      end
      context "without consent" do
        it "redirects back with an alert" do
          expect(CaseWorkerTransmitterJob).not_to receive(:perform_later)
          patch :update
          expect(response).to redirect_to(cbv_flow_submit_path)
          expect(flash[:alert]).to be_present
          expect(flash[:alert]).to eq("Please check the legal agreement box to share your report.")
        end
      end

      context "with consent" do
        it "queues a job and redirects to success screen" do
          expect(CaseWorkerTransmitterJob).to receive(:perform_later).with(cbv_flow.id)
          patch :update, params: { cbv_flow: { consent_to_authorized_use: "1" } }
          expect(response).to redirect_to({ controller: :successes, action: :show })
        end
      end
    end

    describe "with activejob disabled" do
      around do |example|
        ClimateControl.modify ACTIVEJOB_ENABLED: nil do
          example.run
        end
      end

      it "runs the task immediately with consent" do
        expect(CaseWorkerTransmitterJob).to receive(:perform_now)
        patch :update, params: { cbv_flow: { consent_to_authorized_use: "1" } }
        expect(response).to redirect_to({ controller: :successes, action: :show })
      end
    end
  end
end

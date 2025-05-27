require "rails_helper"

RSpec.describe Cbv::SubmitsController do
  include PinwheelApiHelper
  include ArgyleApiHelper
  include_context "gpg_setup"


  let(:current_time) { Date.parse('2024-06-18') }
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
  end

  around do |ex|
    Timecop.freeze(&ex)
  end

  describe "#show" do
    context "when using pinwheel" do
      let(:supported_jobs) { %w[income paystubs employment identity] }
      let(:errored_jobs) { [] }
      let(:employment_errored_at) { nil }
      let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
      let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }

      let(:cbv_flow) do
        create(:cbv_flow,
               :invited,
               :with_pinwheel_account,
               :completed,
               with_errored_jobs: errored_jobs,
               created_at: current_time,
               supported_jobs: supported_jobs,
               cbv_applicant: cbv_applicant
        )
      end

      before do
        cbv_applicant.update(snap_application_date: current_time)
        cbv_flow.payroll_accounts.first.update(pinwheel_account_id: "03e29160-f7e7-4a28-b2d8-813640e030d3")

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

        context "with incomplete cbv_flow" do
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

          it "renders properly" do
            get :show
            expect(controller.send(:has_consent)).to be_falsey
            expect(response.body).to include("Legal agreement")
            expect(response).to be_successful
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

        context "when multiple accounts, one errored one good" do
          let(:supported_jobs) { %w[income paystubs employment] }
          let(:errored_jobs) { [ "employment" ] }

          it "renders a pdf" do
            create(:payroll_account, :pinwheel_fully_synced, cbv_flow: cbv_flow, pinwheel_account_id: "account1")
            expect(response).to be_successful
          end
        end

        context "with sandbox client agency" do
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
              expect(pdf_text).to include(I18n.t("cbv.submits.show.pdf.caseworker.ssn"))
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

              expect(pdf_text).to include(I18n.t("cbv.applicant_informations.sandbox.fields.first_name.prompt"))
              expect(pdf_text).to include(I18n.t("cbv.applicant_informations.sandbox.fields.middle_name.prompt"))
              expect(pdf_text).to include(I18n.t("cbv.applicant_informations.sandbox.fields.last_name.prompt"))
              expect(pdf_text).to include(I18n.t("cbv.applicant_informations.sandbox.fields.case_number.prompt"))
              expect(pdf_text).not_to include(I18n.t("cbv.submits.show.pdf.caseworker.ssn"))
            end
          end
        end

        context "with la_ldh client agency" do
          before do
            cbv_flow.update!(client_agency_id: "la_ldh")
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

              expect(pdf_text).to include("Client-provided information")
              expect(pdf_text).to include("Medicaid case number")
              expect(pdf_text).to include("Date of birth")
              expect(pdf_text).to include("SSN")
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

              expect(pdf_text).to include("Client-provided information")
              expect(pdf_text).to include("Medicaid case number")
              expect(pdf_text).to include("Date of birth")
              expect(pdf_text).not_to include("SSN")
            end
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
    context "when using argyle" do
      context "for Bob (a gig worker)" do
        let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
        let(:account_id) { "019571bc-2f60-3955-d972-dbadfe0913a8" }
        let(:supported_jobs) { %w[accounts identity paystubs] }
        let(:errored_jobs) { [] }
        let(:cbv_flow) do
          create(:cbv_flow,
                 :completed,
                 :invited,
                 :with_argyle_account,
                 with_errored_jobs: errored_jobs,
                 created_at: current_time,
                 supported_jobs: supported_jobs,
                 cbv_applicant: cbv_applicant
          )
        end
        let!(:payroll_account) do
          create(
            :payroll_account,
            :argyle_fully_synced,
            with_errored_jobs: errored_jobs,
            cbv_flow: cbv_flow,
            pinwheel_account_id: account_id,
            supported_jobs: supported_jobs,
            )
        end

        before do
          session[:cbv_flow_id] = cbv_flow.id
          argyle_stub_request_identities_response("bob")
          argyle_stub_request_paystubs_response("bob")
          argyle_stub_request_gigs_response("bob")
          argyle_stub_request_account_response("bob")
        end

        render_views

        it "renders properly" do
          get :show, format: :pdf
          pdf = PDF::Reader.new(StringIO.new(response.body))
          pdf_text = ""
          pdf.pages.each do |page|
            pdf_text += page.text
          end
          pdf_text.gsub! "\n", " "

          expect(response).to be_successful
          expect(pdf_text).to include("Pay Date")
          expect(pdf_text).to include("Gross pay YTD")
          expect(pdf_text).not_to include("Pay period")
          expect(pdf_text).not_to include("Payments after taxes and deductions (net)")
          expect(pdf_text).not_to include("Deduction")
          expect(pdf_text).not_to include("Base Pay")
        end
      end

      context "for Sarah (a w2 worker)" do
        let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
        let(:account_id) { "01956d5f-cb8d-af2f-9232-38bce8531f58" }
        let(:supported_jobs) { %w[accounts identity paystubs employment income] }
        let(:errored_jobs) { [] }
        let(:cbv_flow) do
          create(:cbv_flow,
                 :completed,
                 :invited,
                 created_at: current_time,
                 cbv_applicant: cbv_applicant
          )
        end
        let!(:payroll_account) do
          create(
            :payroll_account,
            :argyle_fully_synced,
            with_errored_jobs: errored_jobs,
            cbv_flow: cbv_flow,
            pinwheel_account_id: account_id,
            supported_jobs: supported_jobs,
            )
        end

        before do
          session[:cbv_flow_id] = cbv_flow.id
          argyle_stub_request_identities_response("sarah")
          argyle_stub_request_paystubs_response("sarah")
          argyle_stub_request_gigs_response("sarah")
          argyle_stub_request_account_response("sarah")
          Timecop.freeze(Time.local(2025, 04, 1, 0, 0))
        end

        render_views

        it "renders properly" do
          get :show, format: :pdf
          pdf = PDF::Reader.new(StringIO.new(response.body))
          pdf_text = ""
          pdf.pages.each do |page|
            pdf_text += page.text
          end
          pdf_text.gsub! "\n", " "

          expect(response).to be_successful
          expect(pdf_text).to include("Pay Date")
          expect(pdf_text).to include("Gross pay YTD")
          expect(pdf_text).to include("Pay period")
          expect(pdf_text).to include("Payment after taxes and deductions (net)")
          expect(pdf_text).to include("Deduction")
          expect(pdf_text).to include("Base Pay")

          expect(pdf_text).to include("$23.16 Hourly")
          expect(pdf_text).not_to include("Nil")
        end
      end
    end
  end

  describe "#update" do
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
    before do
      cbv_applicant.update(snap_application_date: current_time)
      cbv_flow.payroll_accounts.first.update(pinwheel_account_id: "03e29160-f7e7-4a28-b2d8-813640e030d3")

      session[:cbv_flow_id] = cbv_flow.id
      sign_in nyc_user
      pinwheel_stub_request_end_user_accounts_response
      pinwheel_stub_request_end_user_paystubs_response
      pinwheel_stub_request_employment_info_response
      pinwheel_stub_request_income_metadata_response
      pinwheel_stub_request_identity_response
      allow(Aggregators::AggregatorReports::PinwheelReport).to receive(:new).and_return(pinwheel_report)
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

    it "generates a confirmation code" do
      expect(cbv_flow.confirmation_code).to be_nil

      patch :update, params: { cbv_flow: { consent_to_authorized_use: "1" } }

      expect(cbv_flow.reload.confirmation_code).to be_present
      expect(cbv_flow.confirmation_code).to start_with(cbv_flow.client_agency_id.gsub("_", "").upcase)
    end

    it "removes underscores from the agency name in the confirmation code" do
      cbv_flow.update!(client_agency_id: "az_des")
      expect(cbv_flow.confirmation_code).to be_nil

      patch :update, params: { cbv_flow: { consent_to_authorized_use: "1" } }

      expect(cbv_flow.reload.confirmation_code).to start_with("AZDES")
    end

    it "does not overwrite an existing confirmation code" do
      existing_code = "SANDBOX123"
      cbv_flow.update(confirmation_code: existing_code)

      patch :update, params: { cbv_flow: { consent_to_authorized_use: "1" } }

      expect(cbv_flow.reload.confirmation_code).to eq(existing_code)
    end
  end
end

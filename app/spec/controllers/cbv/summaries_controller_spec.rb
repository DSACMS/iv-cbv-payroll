require "rails_helper"

RSpec.describe Cbv::SummariesController do
  include PinwheelApiHelper
  include_context "gpg_setup"

  let(:supported_jobs) { %w[income paystubs employment identity] }
  let(:errored_jobs) { [] }
  let(:current_time) { Date.parse('2024-06-18') }
  let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
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
      pinwheel_stub_request_end_user_accounts_response
      pinwheel_stub_request_end_user_paystubs_response
      pinwheel_stub_request_employment_info_response unless errored_jobs.include?("employment")
      pinwheel_stub_request_income_metadata_response if supported_jobs.include?("income")
      pinwheel_stub_request_identity_response
      pinwheel_stub_request_shifts_response
    end

    context "when rendering views" do
      render_views

      context "with 1 paystub" do
        it "renders properly with 1 paystub" do
          get :show
          doc = Nokogiri::HTML(response.body)

          expect(doc.css("title").text).to include("Review your income report")
          expect(doc.at_xpath("//*[@data-testid=\"summary-description\"]").content).to include("from 2024-03-20 to 2024-06-18")
          expect(doc.at_xpath("//*[@data-testid=\"paystub-table-caption\"]").content).to include("Employer 1: Acme Corporation")
          expect(doc.at_xpath("//*[@data-testid=\"paystub-total-income\"]").content).to include("$4,807.20")
          expect(doc.at_xpath("//tr[@data-testid=\"paystub-row\"]").count).to eq(1)
          expect(doc.at_xpath("//tr[@data-testid=\"paystub-row\"]/td[1]").content).to include("Payment of $4,807.20")
          #
          expect(response).to be_successful
        end
      end
      context "with 3 paystubs" do
        before do
        pinwheel_stub_request_end_user_multiple_paystubs_response
      end
        it "renders properly with 2 paystubs" do
          get :show
          doc = Nokogiri::HTML(response.body)
          expect(response).to be_successful
          expect(doc.css("title").text).to include("Review your income report")
          expect(doc.at_xpath("//*[@data-testid=\"summary-description\"]").content).to include("from 2024-03-20 to 2024-06-18")
          expect(doc.at_xpath("//*[@data-testid=\"paystub-table-caption\"]").content).to include("Employer 1: Acme Corporation")
          expect(doc.at_xpath("//*[@data-testid=\"paystub-total-income\"]").content).to include("$9,614.40")
          expect(doc.at_xpath("//*[@data-testid=\"paystub-table\"]").css("td").count).to eq(2)
          expect(doc.at_xpath("//*[@data-testid=\"paystub-table\"]").css("td")[0].content).to include("Payment of $4,807.20")
          expect(doc.at_xpath("//*[@data-testid=\"paystub-table\"]").css("td")[1].content).to include("Payment of $4,807.20")
        end
      end
    end

    it "tracks events" do
      expect_any_instance_of(MixpanelEventTracker)
        .to receive(:track)
        .with("ApplicantAccessedIncomeSummary", anything, hash_including(
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id
        ))

      expect_any_instance_of(NewRelicEventTracker)
        .to receive(:track)
        .with("ApplicantAccessedIncomeSummary", anything, hash_including(
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id
        ))

      get :show
    end
  end
end

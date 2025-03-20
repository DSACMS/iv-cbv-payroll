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
      stub_request_end_user_accounts_response
      stub_request_end_user_paystubs_response
      stub_request_employment_info_response unless errored_jobs.include?("employment")
      stub_request_income_metadata_response if supported_jobs.include?("income")
      stub_request_identity_response
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        # 90 days before snap_application_date
        start_date = "March 20, 2024"
        # Should be the formatted version of snap_application_date
        end_date = "June 18, 2024"
        expect(assigns[:payments_ending_at]).to eq(end_date)
        expect(assigns[:payments_beginning_at]).to eq(start_date)
        expect(response.body).to include("Review your income report")
        expect(response).to be_successful
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

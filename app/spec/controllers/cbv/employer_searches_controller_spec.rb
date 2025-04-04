require "rails_helper"

RSpec.describe Cbv::EmployerSearchesController do
  include PinwheelApiHelper
  include ArgyleApiHelper

  describe "#show" do
    let(:cbv_flow) { create(:cbv_flow, :invited) }
    let(:pinwheel_token_id) { "abc-def-ghi" }
    let(:user_token) { "foobar" }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(response).to be_successful
      end

      it "tracks a Mixpanel event" do
        expect_any_instance_of(MixpanelEventTracker)
          .to receive(:track)
          .with("ApplicantAccessedSearchPage", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id
          ))
        get :show
      end

      it "tracks a NewRelic event" do
        expect_any_instance_of(NewRelicEventTracker)
          .to receive(:track)
          .with("ApplicantAccessedSearchPage", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id
          ))
        get :show
      end

      it "tracks Mixpanel event when clicking popular payroll providers" do
        expect_any_instance_of(MixpanelEventTracker)
          .to receive(:track)
          .with("ApplicantClickedPopularPayrollProviders", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id
          ))
        get :show, params: { type: "payroll" }
      end

      it "tracks NewRelic event when clicking popular payroll providers" do
        expect_any_instance_of(NewRelicEventTracker)
          .to receive(:track)
          .with("ApplicantClickedPopularPayrollProviders", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id
          ))
        get :show, params: { type: "payroll" }
      end

      it "tracks a Mixpanel event when clicking popular app employers" do
        expect_any_instance_of(MixpanelEventTracker)
          .to receive(:track)
          .with("ApplicantClickedPopularAppEmployers", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id
          ))
        get :show, params: { type: "employer" }
      end

      it "tracks a NewRelic event when clicking popular app employers" do
        expect_any_instance_of(NewRelicEventTracker)
          .to receive(:track)
          .with("ApplicantClickedPopularAppEmployers", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id
          ))
        get :show, params: { type: "employer" }
      end
    end

    context "when there are no employer search results" do
      before do
        pinwheel_stub_request_items_no_items_response
      end

      render_views

      context "when the user at least one payroll_account associated with their cbv_flow" do
        it "renders the view with a link to the summary page" do
          create(:payroll_account, cbv_flow_id: cbv_flow.id)
          get :show, params: { query: "no_results" }
          expect(response).to be_successful
          expect(response.body).to include("continue to review your income report")
          expect(response.body).to include("Review my income report")
        end
      end

      context "when the user has does not have a payroll_account associated with their cbv_flow" do
        it "renders the view with a link to exit income verification" do
          get :show, params: { query: "no_results" }
          expect(response).to be_successful
          expect(response.body).to include("you can exit this site")
          expect(response.body).to include("Exit and go to CBV")
        end
      end
    end

    context "when there are search results" do
      before do
        pinwheel_stub_request_items_response
      end

      render_views

      it "renders successfully" do
        get :show, params: { query: "results" }
        expect(response).to be_successful
      end

      it "tracks a Mixpanel event" do
        expect_any_instance_of(MixpanelEventTracker)
          .to receive(:track)
          .with("ApplicantSearchedForEmployer", anything, hash_including(
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            num_results: 1,
            has_payroll_account: false,
            pinwheel_result_count: 1,
            argyle_result_count: 0
            ))
        get :show, params: { query: "results" }
      end

      it "tracks a NewRelic event" do
        expect_any_instance_of(NewRelicEventTracker)
          .to receive(:track)
          .with("ApplicantSearchedForEmployer", anything, hash_including(
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            num_results: 1,
            has_payroll_account: false,
            pinwheel_result_count: 1,
            argyle_result_count: 0
            ))
        get :show, params: { query: "results" }
      end
    end
  end
end

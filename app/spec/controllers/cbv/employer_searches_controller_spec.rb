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

      it "tracks an event" do
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantAccessedSearchPage", anything, hash_including(
          timestamp: be_a(Integer),
          cbv_applicant_id: cbv_flow.cbv_applicant_id,
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id
        ))
        get :show
      end

      it "tracks event when clicking popular payroll providers" do
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedPopularPayrollProviders", anything, hash_including(
            timestamp: be_a(Integer),
            cbv_applicant_id: cbv_flow.cbv_applicant_id,
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id
          ))
        allow(EventTrackingJob).to receive(:perform_later).with("ApplicantAccessedSearchPage", anything, anything)
        get :show, params: { type: "payroll" }
      end

      it "tracks a Mixpanel event when clicking popular app employers" do
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedPopularAppEmployers", anything, hash_including(
          timestamp: be_a(Integer),
          cbv_applicant_id: cbv_flow.cbv_applicant_id,
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id
        ))
        allow(EventTrackingJob).to receive(:perform_later).with("ApplicantAccessedSearchPage", anything, anything)
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
          expect(response.body).to include("If you have no other jobs to add here, continue")
          expect(response.body).to include("Continue")
          expect(response.body).to include(cbv_flow_applicant_information_path)
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
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with(
          "ApplicantSearchedForEmployer", anything, hash_including(
          cbv_applicant_id: cbv_flow.cbv_applicant_id,
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          num_results: 2,
          has_payroll_account: false,
          pinwheel_result_count: 2,
          argyle_result_count: 0
        ))
        get :show, params: { query: "results" }
      end

      context "when some results should be blocked" do
        before do
          pinwheel_stub_request_items_response
          stub_const("ProviderSearchService::BLOCKED_PINWHEEL_EMPLOYERS", [ "fce3eee0-285b-496f-9b36-30e976194736" ])
        end

        render_views

        it "renders successfully without those results" do
          get :show, params: { query: "results" }
          expect(response).to be_successful
          expect(response.body).not_to include("Acme Payroll")
          expect(response.body).to include("Lumon")
        end
      end
    end
  end
end

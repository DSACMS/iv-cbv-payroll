require "rails_helper"

RSpec.describe Cbv::EmployerSearchesController do
  include PinwheelApiHelper

  describe "#show" do
    let(:cbv_flow) { create(:cbv_flow) }
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

      it "tracks a NewRelic event" do
        expect(NewRelicEventTracker)
          .to receive(:track)
          .with("ApplicantAccessedSearchPage", hash_including(
            timestamp: be_a(Integer),
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id
          ))
        get :show
      end
    end

    context "when there are no employer search results" do
      before do
        stub_request_items_no_items_response
      end

      render_views

      context "when the user at least one pinwheel_account associated with their cbv_flow" do
        it "renders the view with a link to the summary page" do
          create(:pinwheel_account, cbv_flow_id: cbv_flow.id)
          get :show, params: { query: "no_results" }
          expect(response).to be_successful
          expect(response.body).to include("continue to review your income report")
          expect(response.body).to include("Review my income report")
        end
      end

      context "when the user has does not have a pinwheel_account associated with their cbv_flow" do
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
        stub_request_items_response
      end

      render_views

      it "renders successfully" do
        get :show, params: { query: "results" }
        expect(response).to be_successful
      end

      it "tracks a NewRelic event" do
        expect(NewRelicEventTracker)
        .to receive(:track)
        .with("ApplicantAccessedSearchPage", hash_including(
          timestamp: be_a(Integer),
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id
        ))
        expect(NewRelicEventTracker)
          .to receive(:track)
          .with("ApplicantSearchedForEmployer", hash_including(
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            num_results: 1,
            has_pinwheel_account: false
          ))
        get :show, params: { query: "results" }
      end
    end
  end
end

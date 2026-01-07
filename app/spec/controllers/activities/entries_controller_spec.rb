require "rails_helper"

RSpec.describe Activities::EntriesController do
  let(:flow) { create(:activity_flow) }
  render_views

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ACTIVITY_HUB_ENABLED").and_return("true")
  end

  describe '#show' do
    context "with generic link" do
      it 'sets session flow type and id' do
        get :show, params: { client_agency_id: 'sandbox' }
        expect(session[:flow_type]).to eq(:activity)
        expect(session[:flow_id]).to be_present
      end

      context 'when applicant has been set' do
        before do
          cookies.permanent.encrypted[:cbv_applicant_id] = flow.cbv_applicant_id
        end
        it "sets the existing activity flow in the session" do
          expect {
            get :show, params: { client_agency_id: 'sandbox' }
          }.to change(CbvApplicant, :count).by(0)

          expect(session[:flow_type]).to eq(:activity)
          expect(session[:flow_id]).to be_truthy
        end
      end

      context "when no applicant is set" do
        before do
          cookies.permanent.encrypted[:cbv_applicant_id] = nil
        end

        it "creates a new activity flow and sets it in the session" do
          expect {
            get :show, params: { client_agency_id: 'sandbox' }
          }.to change(CbvApplicant, :count).by(1)

          expect(session[:flow_id]).to be_present
        end
      end
    end

    context "with tokenized link" do
      let(:invitation) { create(:activity_flow_invitation) }

      it "creates a flow from the invitation and sets session" do
        get :show, params: { token: invitation.auth_token }

        expect(session[:flow_type]).to eq(:activity)
        expect(session[:flow_id]).to be_present
        expect(ActivityFlow.find(session[:flow_id]).activity_flow_invitation).to eq(invitation)
      end

      it "redirects to root with error for invalid token" do
        get :show, params: { token: "invalid_token" }

        expect(response).to redirect_to(root_url)
        expect(flash[:alert]).to eq(I18n.t("activities.errors.invalid_token"))
      end
    end
  end
  describe "#create" do
    before do
      get :show, params: { client_agency_id: "sandbox" }
    end

    context 'consent box not checked' do
      it "re-renders the form with an error message" do
        post :create, params: { agreement: "0" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash[:alert]).to eq I18n.t("activities.entry.consent_required")
      end
    end
  end

  describe "activity hub access control" do
    it "allows access when ACTIVITY_HUB_ENABLED is true" do
      get :show, params: { client_agency_id: "sandbox" }

      expect(response).not_to redirect_to(root_url)
      expect(response).to have_http_status(:ok)
    end

    it "redirects to home when ACTIVITY_HUB_ENABLED is not set" do
      allow(ENV).to receive(:[]).with("ACTIVITY_HUB_ENABLED").and_return(nil)

      get :show, params: { client_agency_id: "sandbox" }

      expect(response).to redirect_to(root_url)
    end

    it "redirects to home when ACTIVITY_HUB_ENABLED is false" do
      allow(ENV).to receive(:[]).with("ACTIVITY_HUB_ENABLED").and_return("false")

      get :show, params: { client_agency_id: "sandbox" }

      expect(response).to redirect_to(root_url)
    end
  end
end

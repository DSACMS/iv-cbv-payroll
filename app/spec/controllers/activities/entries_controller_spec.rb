require "rails_helper"

RSpec.describe Activities::EntriesController do
  let(:flow) { create(:activity_flow) }
  render_views
  describe '#show' do
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
  describe "#create" do
    context 'consent box not checked' do
      it "redirects the user back with an error message" do
        expect {
          post :create, params: { agreement: "0" }
        }.not_to change { session[:flow_id] }
        expect(response).to redirect_to(activities_flow_entry_path)
        expect(flash[:alert]).to eq I18n.t("cbv.entries.create.error")
      end
    end
  end
end

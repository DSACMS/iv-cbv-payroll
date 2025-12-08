require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  let(:flow) { create(:activity_flow) }

  describe "#show" do
    it "sets flow from token param when provided" do
      flow = create(:activity_flow, token: "abc123")

      get :show, params: { token: "abc123" }

      expect(session[:flow_id]).to eq(flow.id)
      expect(response).to redirect_to(activities_flow_root_path)
    end

    it "redirects to root with error for invalid token" do
      get :show, params: { token: "invalid" }

      expect(response).to redirect_to(root_url)
    end

    it "only shows activities belonging to the current activity flow" do
      other_flow = create(:activity_flow)

      visible_volunteering = flow.volunteering_activities.create!(
        organization_name: "Scoped",
        hours: 1,
        date: Date.new(2000, 1, 1)
      )
      other_flow.volunteering_activities.create!(
        organization_name: "Ignored",
        hours: 2,
        date: Date.new(2000, 2, 2)
      )
      visible_job_training = flow.job_training_activities.create!(
        program_name: "Resume Workshop",
        organization_address: "123 Main St",
        hours: 6
      )
      other_flow.job_training_activities.create!(
        program_name: "Other Workshop",
        organization_address: "456 Elm St",
        hours: 8
      )

      session[:flow_id] = flow.id
      cookies.permanent.encrypted[:cbv_applicant_id] = flow.cbv_applicant_id

      get :index

      expect(assigns(:volunteering_activities)).to match_array([ visible_volunteering ])
      expect(assigns(:job_training_activities)).to match_array([ visible_job_training ])
    end
  end

  describe '#entry' do
    it 'sets session flow type and id' do
      get :entry, params: { client_agency_id: 'sandbox' }
      expect(session[:flow_type]).to eq(:activity)
      expect(session[:flow_id]).to be_present
    end

    context 'when applicant has been set' do
      before do
        cookies.permanent.encrypted[:cbv_applicant_id] = flow.cbv_applicant_id
      end
      it "sets the existing activity flow in the session" do
        expect {
          get :entry, params: { client_agency_id: 'sandbox' }
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
          get :entry, params: { client_agency_id: 'sandbox' }
        }.to change(CbvApplicant, :count).by(1)

        expect(session[:flow_id]).to be_present
      end
    end
  end
end

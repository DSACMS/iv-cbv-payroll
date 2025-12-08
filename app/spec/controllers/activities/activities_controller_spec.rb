require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  let(:flow) { create(:activity_flow) }

  describe "#index" do
    let(:current_flow) { create(:activity_flow) }

    before do
      create(:activity_flow) # ensure there is a second flow that
                             # might get mixed up
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows current flow volunteering activities" do
      expect(
        assigns(:volunteering_activities)
      ).to match_array(
             current_flow.volunteering_activities
           )
    end

    it "shows current flow job training activities" do
      expect(
        assigns(:job_training_activities)
      ).to match_array(
             current_flow.job_training_activities
           )
    end

    it "shows current flow education activities" do
      expect(
        assigns(:education_activities)
      ).to match_array(
             current_flow.education_activities
           )
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

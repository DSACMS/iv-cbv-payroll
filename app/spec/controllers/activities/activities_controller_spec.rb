require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  let(:flow) { create(:activity_flow) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ACTIVITY_HUB_ENABLED").and_return("true")
  end

  describe "#index" do
    let(:current_flow) { create(:activity_flow) }

    before do
      create(:activity_flow) # ensure there is a second flow that might get mixed up
      current_flow.reload

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
end

require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  describe "#show" do
    let(:current_flow) { create(:activity_flow) }

    before do
      create(:activity_flow) # ensure there is a second flow that
                             # might get mixed up
      session[:activity_flow_id] = current_flow.id
      get :show
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

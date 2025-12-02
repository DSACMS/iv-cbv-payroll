require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  describe "#show" do
    it "only shows activities belonging to the current activity flow" do
      flow = create(:activity_flow)
      other_flow = create(:activity_flow)

      visible_activity = flow.volunteering_activities.create!(
        organization_name: "Scoped",
        hours: 1,
        date: Date.new(2000, 1, 1)
      )
      other_flow.volunteering_activities.create!(
        organization_name: "Ignored",
        hours: 2,
        date: Date.new(2000, 2, 2)
      )

      session[:activity_flow_id] = flow.id

      get :show

      expect(assigns(:activities)).to match_array([ visible_activity ])
    end
  end
end

require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  describe "#show" do
    it "only shows activities belonging to the current activity flow" do
      flow = create(:activity_flow)
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

      session[:activity_flow_id] = flow.id

      get :show

      expect(assigns(:volunteering_activities)).to match_array([ visible_volunteering ])
      expect(assigns(:job_training_activities)).to match_array([ visible_job_training ])
    end
  end
end

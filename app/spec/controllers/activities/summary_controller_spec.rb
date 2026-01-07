require "rails_helper"

RSpec.describe Activities::SummaryController, type: :controller do
  render_views

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ACTIVITY_HUB_ENABLED").and_return("true")
  end

  let(:activity_flow) {
    create(
      :activity_flow,
      job_training_activities_count: 0,
      volunteering_activities_count: 0
    )
  }
  let(:other_flow) { create(:activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
  end

  describe "GET #show" do
    it "only shows activities belonging to the current activity flow" do
      visible_volunteering = activity_flow.volunteering_activities.create!(
        organization_name: "Scoped",
        hours: 1,
        date: Date.current
      )
      other_flow.volunteering_activities.create!(
        organization_name: "Ignored",
        hours: 2,
        date: Date.current
      )
      visible_job_training = activity_flow.job_training_activities.create!(
        program_name: "Resume Workshop",
        organization_address: "123 Main St",
        hours: 6
      )
      other_flow.job_training_activities.create!(
        program_name: "Other Workshop",
        organization_address: "456 Elm St",
        hours: 8
      )

      get :show

      expect(assigns(:volunteering_activities)).to match_array([ visible_volunteering ])
      expect(assigns(:job_training_activities)).to match_array([ visible_job_training ])
      expect(response.body).to include("Scoped")
      expect(response.body).to include("Resume Workshop")
    end
  end
end

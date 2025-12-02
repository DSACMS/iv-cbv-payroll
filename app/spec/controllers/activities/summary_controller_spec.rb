require "rails_helper"

RSpec.describe Activities::SummaryController, type: :controller do
  render_views

  let(:activity_flow) { create(:activity_flow) }
  let(:other_flow) { create(:activity_flow) }

  around do |example|
    Timecop.freeze(Time.zone.local(2025, 12, 1, 12, 0, 0)) { example.run }
  end

  before do
    session[:activity_flow_id] = activity_flow.id
  end

  describe "GET #show" do
    it "only shows activities belonging to the current activity flow" do
      visible_volunteering = activity_flow.volunteering_activities.create!(
        organization_name: "Scoped",
        hours: 1,
        date: Date.new(2000, 1, 1)
      )
      other_flow.volunteering_activities.create!(
        organization_name: "Ignored",
        hours: 2,
        date: Date.new(2000, 2, 2)
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

  describe "POST #create" do
    it "marks the flow as completed and redirects to success" do
      post :create

      expect(activity_flow.reload.completed_at).to eq(Time.zone.local(2025, 12, 1, 12, 0, 0))
      expect(response).to redirect_to(activities_flow_success_path)
    end
  end
end

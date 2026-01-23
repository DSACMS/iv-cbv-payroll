require "rails_helper"

RSpec.describe Activities::SummaryController, type: :controller do
  include_context "activity_hub"

  render_views

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
    session[:flow_type] = :activity
  end

  describe "GET #show" do
    it "only shows activities belonging to the current activity flow" do
      visible_volunteering = create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Scoped", hours: 1)
      create(:volunteering_activity, activity_flow: other_flow, organization_name: "Ignored", hours: 2)
      visible_job_training = create(:job_training_activity, activity_flow: activity_flow, program_name: "Resume Workshop", organization_address: "123 Main St", hours: 6)
      create(:job_training_activity, activity_flow: other_flow, program_name: "Other Workshop", organization_address: "456 Elm St", hours: 8)

      get :show

      expect(assigns(:volunteering_activities)).to contain_exactly(visible_volunteering)
      expect(assigns(:job_training_activities)).to contain_exactly(visible_job_training)
      expect(response.body).to include("Scoped")
      expect(response.body).to include("Resume Workshop")
    end
  end
end

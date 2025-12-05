require "rails_helper"

RSpec.describe Activities::EducationController, type: :controller do
  render_views

  let(:identity) { create(:identity, activity_flows_count: 0) }
  let(:activity_flow) { create(:activity_flow, identity: identity) }

  describe "#create" do
    let(:education_activity) { create(:education_activity, activity_flow: activity_flow ) }

    it "creates a new education activity and returns to the hub" do
      expect(education_activity.confirmed).to be(false)

      post :create, params: { education_activity_id: education_activity }, session: { activity_flow_id: activity_flow.id }

      expect(education_activity.confirmed).to be(true)
      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.education.created"))
    end
  end
end

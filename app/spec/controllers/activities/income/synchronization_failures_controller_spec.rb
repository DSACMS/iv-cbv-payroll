require "rails_helper"

RSpec.describe Activities::Income::SynchronizationFailuresController do
  include_context "activity_hub"
  describe "#show" do
    render_views

    let(:flow) { create(:activity_flow) }

    before do
      session[:flow_id] = flow.id
      session[:flow_type] = :activity
    end

    it "shows the add employment manually button" do
      get :show

      expect(response.body).to include(I18n.t("activities.income.synchronization_failures.show.add_employment_manually"))
    end
  end
end

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

    it "renders the activity flow header with exit button" do
      get :show

      expect(response.body).to include(I18n.t("activities.employment.title_singular"))
      expect(response.body).to include("exit-confirmation-modal")
    end

    it "enables the existing exit and retry navigation events" do
      get :show

      rendered = Capybara.string(response.body)
      expect(rendered).to have_selector("[data-activity-flow-header-track-event-prefix-value='Employment']")
      expect(rendered).to have_selector("a[data-action='click->employment-payroll-navigation#back']")
    end
  end
end

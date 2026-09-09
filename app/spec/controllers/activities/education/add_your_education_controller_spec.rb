require "rails_helper"

RSpec.describe Activities::Education::AddYourEducationController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "#show" do
    it "renders properly" do
      get :show
      expect(response).to be_successful
    end

    it "renders the header, reporting period, and description" do
      get :show
      expect(response.body).to include(I18n.t("activities.education.add_your_education.show.header"))
      expect(response.body).to include(I18n.t("activities.education.add_your_education.show.reporting_period_label"))
      expect(response.body).to include(activity_flow.reporting_window_display)
      expect(response.body).to include(CGI.escapeHTML(I18n.t("activities.education.add_your_education.show.description")))
    end

    it "renders all three options with bolded labels and their hints" do
      get :show

      %w[college high_school_ged trade_or_technical].each do |option|
        label = CGI.escapeHTML(I18n.t("activities.education.add_your_education.show.options.#{option}.label"))
        expect(response.body).to include("<span class=\"text-bold\">#{label}</span>")
        expect(response.body).to include(CGI.escapeHTML(I18n.t("activities.education.add_your_education.show.options.#{option}.hint")))
      end
    end

    it "does not render the hint as an attribute on the radio input" do
      get :show
      expect(response.body).not_to include("hint=")
    end

    it "renders the activity flow header with exit button and no back link" do
      get :show
      expect(response.body).to include(I18n.t("activities.education.title_singular"))
      expect(response.body).to include("exit-confirmation-modal")
      expect(Capybara.string(response.body)).not_to have_link("Back")
    end
  end

  describe "#create" do
    it "redirects to verify enrollment when college or university is selected" do
      post :create, params: { add_education_method: "college_or_university" }
      expect(response).to redirect_to(verify_activities_flow_education_index_path)
    end

    it "redirects to self-attested education when high school or GED is selected" do
      post :create, params: { add_education_method: "high_school_ged" }
      expect(response).to redirect_to(new_activities_flow_education_path)
    end

    it "redirects to self-attested education when trade or technical program is selected" do
      post :create, params: { add_education_method: "trade_or_technical" }
      expect(response).to redirect_to(new_activities_flow_education_path)
    end

    it "redirects back with an alert when nothing is selected" do
      post :create
      expect(flash[:slim_alert][:message]).to eq(I18n.t("shared.next_path.notice_no_answer"))
      expect(response).to redirect_to(activities_flow_education_add_your_education_path)
    end

    it "redirects back with an alert when the selection is not recognized" do
      post :create, params: { add_education_method: "something_else" }
      expect(flash[:slim_alert][:message]).to eq(I18n.t("shared.next_path.notice_no_answer"))
      expect(response).to redirect_to(activities_flow_education_add_your_education_path)
    end
  end
end

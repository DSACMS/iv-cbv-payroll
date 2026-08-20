require "rails_helper"

RSpec.describe Activities::Employment::AddYourWorkController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow) }
  let(:tracked_flow) { activity_flow }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "#show" do
    let(:perform_tracked_action) { get :show }

    it "renders properly" do
      get :show
      expect(response).to be_successful
    end

    it "renders the header and description" do
      get :show
      expect(response.body).to include(I18n.t("activities.employment.add_your_work.show.header"))
      expect(response.body).to include(CGI.escapeHTML(I18n.t("activities.employment.add_your_work.show.description")))
    end

    it "renders all three options with bolded labels and their hints" do
      get :show

      %w[automatic paid unpaid].each do |option|
        label = CGI.escapeHTML(I18n.t("activities.employment.add_your_work.show.options.#{option}.label"))
        expect(response.body).to include("<span class=\"text-bold\">#{label}</span>")
        expect(response.body).to include(CGI.escapeHTML(I18n.t("activities.employment.add_your_work.show.options.#{option}.hint")))
      end
    end

    it "does not render the hint as an attribute on the radio input" do
      get :show
      expect(response.body).not_to include("hint=")
    end

    it "renders the activity flow header with exit button and no back link" do
      get :show
      expect(response.body).to include(I18n.t("activities.employment.title_singular"))
      expect(response.body).to include("exit-confirmation-modal")
      expect(Capybara.string(response.body)).not_to have_link("Back")
    end

    it_behaves_like "tracks an event", TrackEvent::EmploymentAddYourWorkViewed
  end

  describe "#create" do
    it "redirects to employer search when connecting work automatically" do
      post :create, params: { add_work_method: "connect_automatically" }
      expect(response).to redirect_to(activities_flow_income_employer_search_path)
    end

    it "redirects to self-attested employment when entering paid work manually" do
      post :create, params: { add_work_method: "enter_paid_manually" }
      expect(response).to redirect_to(new_activities_flow_income_employment_path)
    end

    it "redirects to self-attested employment when entering unpaid work manually" do
      post :create, params: { add_work_method: "enter_unpaid_manually" }
      expect(response).to redirect_to(new_activities_flow_income_employment_path)
    end

    it "redirects back with an alert when nothing is selected" do
      post :create
      expect(flash[:slim_alert][:message]).to eq(I18n.t("shared.next_path.notice_no_answer"))
      expect(response).to redirect_to(activities_flow_income_add_your_work_path)
    end

    it "redirects back with an alert when the selection is not recognized" do
      post :create, params: { add_work_method: "something_else" }
      expect(flash[:slim_alert][:message]).to eq(I18n.t("shared.next_path.notice_no_answer"))
      expect(response).to redirect_to(activities_flow_income_add_your_work_path)
    end

    it "does not track a submitted event when nothing is selected" do
      expect(EventTrackingJob).not_to receive(:perform_later)
        .with(TrackEvent::EmploymentAddYourWorkSubmitted, anything, anything)

      post :create
    end

    %w[connect_automatically enter_paid_manually enter_unpaid_manually].each do |add_work_method|
      context "when the applicant selects #{add_work_method}" do
        let(:perform_tracked_action) { post :create, params: { add_work_method: add_work_method } }

        it_behaves_like "tracks an event", TrackEvent::EmploymentAddYourWorkSubmitted,
          extra_attributes: -> { { add_work_method: add_work_method } }
      end
    end
  end
end

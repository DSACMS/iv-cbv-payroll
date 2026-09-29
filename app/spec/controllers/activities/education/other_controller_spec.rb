require "rails_helper"

RSpec.describe Activities::Education::OtherController, type: :controller do
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

    it "renders the header" do
      get :show
      expect(response.body).to include(I18n.t("activities.education.other.show.header"))
    end

    it "renders the activity flow header with exit button and back link to education type selection" do
      get :show
      expect(response.body).to include(I18n.t("activities.education.title_singular"))
      expect(response.body).to include("exit-confirmation-modal")
      expect(Capybara.string(response.body)).to have_link("Back", href: activities_flow_education_add_your_education_path)
    end

    it "renders the accordions with content and routing links" do
      get :show
      page = Capybara.string(response.body)

      # Section 1: not listed
      expect(response.body).to include(I18n.t("activities.education.other.show.accordion.not_listed.title"))
      expect(response.body).to include(I18n.t("activities.education.other.show.accordion.not_listed.body"))
      expect(page).to have_link(
        I18n.t("activities.education.other.show.accordion.not_listed.link"),
        href: new_activities_flow_education_path
      )

      # Section 2: job training
      expect(response.body).to include(I18n.t("activities.education.other.show.accordion.job_training.title"))
      expect(response.body).to include(I18n.t("activities.education.other.show.accordion.job_training.body"))
      expect(page).to have_link(
        I18n.t("activities.education.other.show.accordion.job_training.link"),
        href: new_activities_flow_job_training_path
      )

      # Section 3: internship / apprenticeship
      expect(response.body).to include(I18n.t("activities.education.other.show.accordion.internship.title"))
      expect(response.body).to include(I18n.t("activities.education.other.show.accordion.internship.body"))
      expect(page).to have_link(
        I18n.t("activities.education.other.show.accordion.internship.link"),
        href: activities_flow_income_add_your_work_path
      )
    end

    it "renders the exit link" do
      get :show
      page = Capybara.string(response.body)

      expect(page).to have_link(
        I18n.t("activities.education.other.show.exit_to_home"),
        href: activities_flow_root_path
      )
    end
  end
end

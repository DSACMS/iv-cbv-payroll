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
    context "with link analytics" do
      let(:rendered) { Capybara.string(response.body) }

      before { get :show }

      context "for education not listed" do
        let(:link) do
          rendered.find_link(I18n.t("activities.education.other.show.accordion.not_listed.link"))
        end

        it "tracks the not-listed link and preserves manual education entry" do
          expect(link[:href]).to eq(new_activities_flow_education_path(education_type: "other"))
          expect(link["data-controller"]).to eq("education-other")
          expect(link["data-action"]).to eq("click->education-other#trackLink")
          expect(link["data-education-other-link-param"]).to eq("not_listed")
        end
      end

      context "for job training" do
        let(:link) do
          rendered.find_link(I18n.t("activities.education.other.show.accordion.job_training.link"))
        end

        it "tracks the job-training link and preserves work program entry" do
          expect(link[:href]).to eq(new_activities_flow_job_training_path)
          expect(link["data-controller"]).to eq("education-other")
          expect(link["data-action"]).to eq("click->education-other#trackLink")
          expect(link["data-education-other-link-param"]).to eq("job_training")
        end
      end

      context "for internships" do
        let(:link) do
          rendered.find_link(I18n.t("activities.education.other.show.accordion.internship.link"))
        end

        it "tracks the internship link and preserves unpaid work entry" do
          expect(link[:href]).to eq(new_activities_flow_income_employment_path(
            compensation_type: "unpaid_or_in_kind", back_url: "education_other"))
          expect(link["data-controller"]).to eq("education-other")
          expect(link["data-action"]).to eq("click->education-other#trackLink")
          expect(link["data-education-other-link-param"]).to eq("internship")
        end
      end

      context "for returning home" do
        let(:link) { rendered.find_link(I18n.t("activities.education.other.show.exit_to_home")) }

        it "tracks the home link and preserves the activity hub destination" do
          expect(link[:href]).to eq(activities_flow_root_path)
          expect(link["data-controller"]).to eq("education-other")
          expect(link["data-action"]).to eq("click->education-other#trackLink")
          expect(link["data-education-other-link-param"]).to eq("exit_to_home")
        end
      end
    end

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
        href: new_activities_flow_education_path(education_type: "other")
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
        href: new_activities_flow_income_employment_path(compensation_type: "unpaid_or_in_kind", back_url: "education_other")
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

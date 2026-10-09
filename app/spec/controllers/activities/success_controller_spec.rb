require "rails_helper"

RSpec.describe Activities::SuccessController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #show" do
    it "redirects to summary if the flow has not been submitted" do
      get :show

      expect(response).to redirect_to(activities_flow_summary_path)
    end

    it "displays the links for downloading and to get to the survey" do
      activity_flow.touch(:completed_at)

      get :show

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(activities_flow_submit_path(format: :pdf))
      expect(response.body).to include(I18n.t("activities.success.show.download_pdf"))
      expect(response.body).to include(feedbacks_path(form: "survey"))
    end

    it "displays the community engagement next steps" do
      activity_flow.touch(:completed_at)

      get :show

      rendered = Capybara.string(response.body)
      expect(rendered).to have_selector(".usa-icon-list__item", count: 1)
      expect(rendered).to have_text(I18n.t("activities.success.show.whats_next_1_title"))
      expect(rendered).to have_no_text(I18n.t("activities.success.show.employment.whats_next.head_of_household.heading"))
    end

    it "displays the employment-focused next steps" do
      activity_flow.update!(completed_at: Time.current, employment_focused: true)

      get :show

      rendered = Capybara.string(response.body)
      download_link = rendered.find_link(I18n.t("activities.success.show.download_pdf"))

      expect(rendered).to have_selector(".usa-icon-list__item", count: 3)
      expect(rendered).to have_text(I18n.t("activities.success.show.employment.whats_next.head_of_household.heading"))
      expect(rendered).to have_text(I18n.t("activities.success.show.employment.whats_next.household_member.heading"))
      expect(download_link[:class]).to include("usa-button--outline")
      expect(download_link[:rel]).to eq("noopener noreferrer")
    end

    it "displays the confirmation code" do
      completed_time = Time.zone.now
      confirmation_code = "SANDBOX123"
      activity_flow.update!(completed_at: completed_time, confirmation_code: confirmation_code)

      get :show

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(confirmation_code)
      expect(response.body).to include(I18n.t("activities.success.show.confirmation_code_html", confirmation_code: confirmation_code))
    end
  end
end

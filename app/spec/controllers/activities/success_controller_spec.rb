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
    context "with a named applicant in a tokenized flow" do
      let(:applicant) { create(:cbv_applicant, first_name: "Lisa", last_name: "Williams") }
      let(:invitation) { create(:activity_flow_invitation, cbv_applicant: applicant) }
      let(:activity_flow) { create(:activity_flow, cbv_applicant: applicant, activity_flow_invitation: invitation, completed_at: Time.current) }

      before { get :show }

      it "does not display the reporting banner" do
        expect(response).to have_http_status(:ok)
        expect(Capybara.string(response.body)).to have_no_text("Reporting for")
      end
    end

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

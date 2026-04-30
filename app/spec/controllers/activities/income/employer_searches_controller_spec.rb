require "rails_helper"

RSpec.describe Activities::Income::EmployerSearchesController do
  include PinwheelApiHelper
  include ArgyleApiHelper
  include_context "activity_hub"

  describe "#show" do
    let(:activity_flow) { create(:activity_flow) }

    before do
      session[:flow_id] = activity_flow.id
      session[:flow_type] = :activity
    end

    render_views

    it "renders properly" do
      get :show
      expect(response).to be_successful
    end

    it "renders the activity flow header with exit button" do
      get :show
      expect(response.body).to include(I18n.t("activities.employment.title_singular"))
      expect(response.body).to include("exit-confirmation-modal")
    end

    it "tracks an accessed search event with activity_flow_id" do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantAccessedSearchPage", anything, hash_including(
        time: be_a(Integer),
        cbv_applicant_id: activity_flow.cbv_applicant_id,
        activity_flow_id: activity_flow.id,
        invitation_id: activity_flow.activity_flow_invitation_id
      ))

      get :show
    end

    context "when there are search results" do
      before do
        pinwheel_stub_request_items_response
        argyle_stub_request_employer_search_response("bob")
      end

      it "tracks a searched-for-employer event with activity_flow_id" do
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with(
          "ApplicantSearchedForEmployer", anything, hash_including(
            cbv_applicant_id: activity_flow.cbv_applicant_id,
            activity_flow_id: activity_flow.id,
            invitation_id: activity_flow.activity_flow_invitation_id,
            num_results: 8,
            has_payroll_account: false,
            pinwheel_result_count: 0,
            argyle_result_count: 8
          )
        )

        get :show, params: { query: "results" }
      end

      it "shows the add employment manually button instead of the employer not listed link" do
        get :show, params: { query: "results" }

        expect(response.body).to include(I18n.t("activities.income.employer_searches.employer.add_employment_manually"))
        expect(response.body).not_to include(I18n.t("cbv.employer_searches.show.employer_not_listed"))
      end
    end

    context "when there are no search results" do
      before do
        pinwheel_stub_request_items_no_items_response
        argyle_stub_request_employer_search_response("empty")
      end

      it "shows the activity flow no results content with add employment manually button" do
        get :show, params: { query: "no_results" }

        expect(response.body).to include(CGI.escapeHTML(I18n.t("activities.income.employer_searches.employer.no_results_title")))
        expect(response.body).to include(I18n.t("activities.income.employer_searches.employer.no_results_body"))
        expect(response.body).to include(I18n.t("activities.income.employer_searches.employer.add_employment_manually"))
      end

      it "does not show the CBV troubleshooting steps or zero results heading" do
        get :show, params: { query: "no_results" }

        expect(response.body).not_to include(I18n.t("cbv.employer_searches.show.no_results_steps_title"))
        expect(response.body).not_to include(I18n.t("cbv.employer_searches.show.results", count: 0))
      end
    end

    it "renders the activity flow help alert" do
      get :show

      expect(response.body).to include(CGI.escapeHTML(I18n.t("activities.income.employer_searches.show.alert.heading")))
      expect(response.body).to include(I18n.t("activities.income.employer_searches.show.add_employment_manually"))
    end

    it "does not render Common questions content" do
      get :show
      expect(response.body).not_to include(I18n.t("cbv.employer_searches.show.common_questions_header"))
      expect(response.body).not_to include(I18n.t("cbv.employer_searches.show.lost_job_title"))
      expect(response.body).not_to include(I18n.t("cbv.employer_searches.show.no_income_title"))
    end

    it "tracks popular payroll provider clicks with activity_flow_id" do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
      allow(EventTrackingJob).to receive(:perform_later).with("ApplicantAccessedSearchPage", anything, anything)
      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedPopularPayrollProviders", anything, hash_including(
        time: be_a(Integer),
        cbv_applicant_id: activity_flow.cbv_applicant_id,
        activity_flow_id: activity_flow.id,
        invitation_id: activity_flow.activity_flow_invitation_id
      ))

      get :show, params: { type: "payroll" }
    end

    it "tracks popular app employer clicks with activity_flow_id" do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
      allow(EventTrackingJob).to receive(:perform_later).with("ApplicantAccessedSearchPage", anything, anything)
      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedPopularAppEmployers", anything, hash_including(
        time: be_a(Integer),
        cbv_applicant_id: activity_flow.cbv_applicant_id,
        activity_flow_id: activity_flow.id,
        invitation_id: activity_flow.activity_flow_invitation_id
      ))

      get :show, params: { type: "employer" }
    end
  end
end

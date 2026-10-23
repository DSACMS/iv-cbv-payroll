require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  include_context "activity_hub"
  render_views

  describe "common questions" do
    let(:current_flow) do
      create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0,
        education_activities_count: 0, reporting_window_months: 1)
    end
    let(:rendered) { Capybara.string(response.body) }
    let(:reporting_purpose) { I18n.t("activities.hub.common_questions.reporting_purposes.application") }
    let(:required_month_count) { 1 }
    let(:requirements_body) do
      ActionController::Base.helpers.strip_tags(
        I18n.t("activities.hub.common_questions.requirements_body_html",
          count: required_month_count, required_month_count: required_month_count)
      )
    end
    let(:income_body) { I18n.t("activities.hub.common_questions.income_body", reporting_purpose: reporting_purpose) }

    before do
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
    end

    it "shows both questions on an empty hub" do
      get :index

      expect(rendered).to have_selector("h2", text: I18n.t("activities.hub.common_questions.heading"))
      expect(rendered).to have_button(I18n.t("activities.hub.common_questions.requirements_title"))
      expect(rendered).to have_button(I18n.t("activities.hub.common_questions.income_title"))
      expect(rendered).to have_no_button(I18n.t("activities.hub.review_and_submit"))
    end

    it "uses the application requirements and reporting purpose" do
      get :index

      expect(rendered).to have_text(requirements_body)
      expect(rendered).to have_text(income_body)
    end

    context "with activities to review" do
      before { create(:volunteering_activity, activity_flow: current_flow) }

      it "provides the review action when activities have been added" do
        get :index

        expect(rendered).to have_button(I18n.t("activities.hub.review_and_submit"))
        expect(rendered).to have_selector("form[action='#{controller.next_path}'][method='get']")
      end
    end

    context "with an 11-month renewal requiring a subset of months" do
      let(:required_month_count) { 2 }

      let(:current_flow) do
        create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0,
          education_activities_count: 0, reporting_window_type: "renewal", reporting_window_months: 11,
          renewal_required_months: 2)
      end

      it "uses the required month count and the application purpose" do
        get :index

        expect(rendered).to have_text(requirements_body)
        expect(rendered).to have_text(income_body)
      end
    end

    context "with a 12-month application" do
      let(:reporting_purpose) { I18n.t("activities.hub.common_questions.reporting_purposes.renewal") }
      let(:current_flow) do
        create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0,
          education_activities_count: 0, reporting_window_type: "application", reporting_window_months: 12)
      end

      it "uses the renewal purpose based on the lookback period" do
        get :index

        expect(rendered).to have_text(income_body)
      end
    end

    context "with a lookback period greater than 12 months" do
      let(:reporting_purpose) { I18n.t("activities.hub.common_questions.reporting_purposes.renewal") }
      let(:current_flow) do
        create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0,
          education_activities_count: 0, reporting_window_type: "application", reporting_window_months: 13)
      end

      it "uses the renewal purpose" do
        get :index

        expect(rendered).to have_text(income_body)
      end
    end
  end

  describe "#index" do
    let(:current_flow) { create(:activity_flow) }
    let(:tracked_flow) { current_flow }
    let(:perform_tracked_action) { get :index }

    before do
      create(:activity_flow) # ensure there is a second flow that might get mixed up
      current_flow.reload
      activity = create(:volunteering_activity, activity_flow: current_flow, organization_name: "Food Pantry")
      create(:volunteering_activity_month, volunteering_activity: activity, month: current_flow.reporting_window_range.begin, hours: 5)

      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it_behaves_like "tracks an event", TrackEvent::HubViewed

    it "does not include from_edit/from_review navigation params in the tracked event, even when present in the request" do
      expect(EventTrackingJob).to receive(:perform_later).with(
        TrackEvent::HubViewed,
        anything,
        hash_excluding(:from_edit, :from_review)
      )

      get :index, params: { from_edit: 1, from_review: 1 }
    end

    it "points the employment add button at the add your work page" do
      expect(Capybara.string(response.body)).to have_css(
        "[data-activity-type='employment'] form[action='#{activities_flow_income_add_your_work_path}']"
      )
    end

    context "with unpaid-only employment" do
      let(:current_flow) { create(:activity_flow, unpaid_work_only: true) }

      it "renders an unpaid work section in place of employment" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_selector("[data-activity-type='unpaid_work'] h2", text: I18n.t("activities.unpaid_work.title"))
        expect(rendered).to have_text(I18n.t("activities.hub.empty.unpaid_work"))
        expect(rendered).to have_no_selector("[data-activity-type='employment']")
      end

      it "uses the existing employment cards for unpaid work" do
        activity = create(:employment_activity, activity_flow: current_flow, compensation_type: :unpaid_or_in_kind, employer_name: "Example unpaid work")
        create(:employment_activity_month, employment_activity: activity, month: current_flow.reporting_months.first, hours: 12, gross_income: 0)
        get :index

        section = Capybara.string(response.body).find("[data-activity-type='unpaid_work']")
        expect(section).to have_text("Example unpaid work")
        expect(section).to have_text(I18n.t("activities.hub.cards.hours", count: "12"))
        expect(section).to have_no_text(I18n.t("activities.hub.cards.gross_income", amount: "$0.00"))
        expect(section).to have_link(I18n.t("activities.hub.edit"), href: review_activities_flow_income_employment_path(id: activity, from_edit: 1))
      end

      it "points the employment add button directly at the unpaid work form" do
        form = Capybara.string(response.body).find("[data-activity-type='unpaid_work'] form")

        expect(form[:action]).to eq(new_activities_flow_income_employment_path(compensation_type: "unpaid_or_in_kind"))
      end
    end

    it "shows current flow community service activities" do
      expect(
        assigns(:community_service_activities)
      ).to match_array(
             current_flow.volunteering_activities
           )
    end

    it "shows current flow work programs activities" do
      expect(
        assigns(:work_programs_activities)
      ).to match_array(
             current_flow.job_training_activities
           )
    end

    it "shows current flow education activities" do
      expect(
        assigns(:education_activities)
      ).to match_array(
             current_flow.education_activities
           )
    end

    it "shows the hub heading, reporting period, and months required" do
      rendered = Capybara.string(response.body)

      expect(rendered).to have_selector("h1", text: I18n.t("activities.hub.title"))
      expect(rendered).to have_selector("p", text: "#{I18n.t("activities.hub.empty_state_reporting_period_label")} #{current_flow.reporting_window_display}", exact_text: true, normalize_ws: true)
      expect(rendered).to have_selector("p", text: "#{I18n.t("activities.hub.months_required_label")} #{current_flow.required_month_count}", exact_text: true, normalize_ws: true)
    end

    context "with an invitation for the last twelve complete months" do
      let(:invitation) { create(:activity_flow_invitation, verification_range: "last_12_complete_months") }
      let(:current_flow) { create(:activity_flow, activity_flow_invitation: invitation) }

      it "shows renewal months-required wording with activities added" do
        expect(Capybara.string(response.body)).to have_selector("p",
          text: "#{I18n.t("activities.hub.months_required_label")} #{I18n.t("activities.hub.months_required_any", count: current_flow.required_month_count)}",
          exact_text: true, normalize_ws: true)
      end
    end
  end

  describe "hiding draft activities on the hub" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }

    before do
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
    end

    it "hides draft activities from the hub" do
      completed = create(:volunteering_activity, activity_flow: current_flow, draft: false)
      _draft = create(:volunteering_activity, activity_flow: current_flow, draft: true)

      get :index

      expect(assigns(:community_service_activities)).to contain_exactly(completed)
    end

    it "shows all published activities" do
      activity = create(:volunteering_activity, activity_flow: current_flow, draft: false)

      get :index

      expect(assigns(:community_service_activities)).to contain_exactly(activity)
    end

    it "only hides draft activities of the matching type" do
      _draft_volunteering = create(:volunteering_activity, activity_flow: current_flow, draft: true)
      published_job_training = create(:job_training_activity, activity_flow: current_flow, draft: false)

      get :index

      expect(assigns(:community_service_activities)).to be_empty
      expect(assigns(:work_programs_activities)).to contain_exactly(published_job_training)
    end

    it "hides draft payroll accounts from the hub" do
      kept = create(:payroll_account, :pinwheel_fully_synced, flow: current_flow, draft: false)
      _draft = create(:payroll_account, :pinwheel_fully_synced, flow: current_flow, draft: true)

      get :index

      expect(assigns(:employment_payroll_accounts)).to contain_exactly(kept)
    end

    it "hides review and submit when the only activity is a draft" do
      create(:volunteering_activity, activity_flow: current_flow, draft: true)

      get :index

      expect(response.body).not_to include(I18n.t("activities.hub.review_and_submit"))
    end

    it "shows review and submit when a published activity exists alongside a draft" do
      create(:volunteering_activity, activity_flow: current_flow, draft: false)
      create(:job_training_activity, activity_flow: current_flow, draft: true)

      get :index

      expect(response.body).to include(I18n.t("activities.hub.review_and_submit"))
    end
  end

  context "when no activities are added" do
    let(:current_flow) do
      create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0)
    end

    before do
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "renders empty-state copy for all sections and hides review and submit" do
      expect(response.body).to include(I18n.t("activities.hub.empty.employment"))
      expect(response.body).to include(I18n.t("activities.hub.empty.education"))
      expect(response.body).to include(I18n.t("activities.hub.empty.community_service"))
      expect(response.body).to include(I18n.t("activities.hub.empty.work_programs"))
      expect(response.body).not_to include(I18n.t("activities.hub.review_and_submit"))
    end

    it "shows the hub heading, reporting period, and months required" do
      rendered = Capybara.string(response.body)

      expect(rendered).to have_selector("h1", text: I18n.t("activities.hub.title"))
      expect(rendered).to have_selector("p", text: "#{I18n.t("activities.hub.empty_state_reporting_period_label")} #{current_flow.reporting_window_display}", exact_text: true, normalize_ws: true)
      expect(rendered).to have_selector("p", text: "#{I18n.t("activities.hub.months_required_label")} #{current_flow.required_month_count}", exact_text: true, normalize_ws: true)
    end

    context "with a single-month reporting window" do
      let(:current_flow) do
        create(
          :activity_flow,
          volunteering_activities_count: 0,
          job_training_activities_count: 0,
          education_activities_count: 0,
          reporting_window_months: 1
        )
      end

      it "shows the empty-state reporting period with one month label" do
        rendered = Capybara.string(response.body)
        reporting_month = I18n.l(current_flow.reporting_window_range.begin, format: :month_year)

        expect(rendered).to have_selector("p", text: "#{I18n.t("activities.hub.empty_state_reporting_period_label")} #{reporting_month}", exact_text: true, normalize_ws: true)
      end
    end

    it "renders the two-column container" do
      expect(response.body).to include("activity-hub-columns")
    end
  end

  context "when at least one activity is added" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }

    before do
      create(:volunteering_activity, activity_flow: current_flow, hours: 1)
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "does not show empty state for community service and shows review and submit" do
      expect(response.body).not_to include(I18n.t("activities.hub.empty.community_service"))
      expect(response.body).to include(I18n.t("activities.hub.review_and_submit"))
    end
  end

  context "when activity requirements are completed" do
    let(:current_flow) do
      create(
        :activity_flow,
        reporting_window_months: 1,
        volunteering_activities_count: 0,
        job_training_activities_count: 0,
        education_activities_count: 0
      )
    end

    before do
      activity = create(:volunteering_activity, activity_flow: current_flow)
      create(
        :volunteering_activity_month,
        volunteering_activity: activity,
        month: current_flow.reporting_window_range.begin,
        hours: 90
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows the hub heading, reporting period, and months required" do
      rendered = Capybara.string(response.body)

      expect(rendered).to have_selector("h1", text: I18n.t("activities.hub.title"))
      expect(rendered).to have_selector("p", text: "#{I18n.t("activities.hub.empty_state_reporting_period_label")} #{current_flow.reporting_window_display}", exact_text: true, normalize_ws: true)
      expect(rendered).to have_selector("p", text: "#{I18n.t("activities.hub.months_required_label")} #{current_flow.required_month_count}", exact_text: true, normalize_ws: true)
    end
  end

  context "when earnings meet threshold but hours do not" do
    let(:current_flow) do
      create(
        :activity_flow,
        reporting_window_months: 1,
        volunteering_activities_count: 0,
        job_training_activities_count: 0,
        education_activities_count: 0
      )
    end

    before do
      employment_activity = create(:employment_activity, activity_flow: current_flow)
      create(
        :employment_activity_month,
        employment_activity: employment_activity,
        month: current_flow.reporting_window_range.begin,
        hours: 0,
        gross_income: 600
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows the hub heading and reporting period" do
      rendered = Capybara.string(response.body)

      expect(rendered).to have_selector("h1", text: I18n.t("activities.hub.title"))
      expect(rendered).to have_selector("p", text: "#{I18n.t("activities.hub.empty_state_reporting_period_label")} #{current_flow.reporting_window_display}", exact_text: true, normalize_ws: true)
    end
  end

  context "when activities are added for a renewal flow" do
    context "when subset required months are configured and completed" do
      let(:current_flow) do
        stub_client_agency_config_value("sandbox", "renewal_required_months", 2)
        create(
          :activity_flow,
          reporting_window_type: "renewal",
          reporting_window_months: 6,
          volunteering_activities_count: 0,
          job_training_activities_count: 0,
          education_activities_count: 0
        )
      end

      before do
        activity = create(:volunteering_activity, activity_flow: current_flow)
        create(
          :volunteering_activity_month,
          volunteering_activity: activity,
          month: current_flow.reporting_months.first.beginning_of_month,
          hours: 80
        )
        create(
          :volunteering_activity_month,
          volunteering_activity: activity,
          month: current_flow.reporting_months.second.beginning_of_month,
          hours: 80
        )

        session[:flow_id] = current_flow.id
        session[:flow_type] = :activity
        get :index
      end

      it "shows renewal months-required copy when required months are complete" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_selector("p",
          text: "#{I18n.t("activities.hub.months_required_label")} #{I18n.t("activities.hub.months_required_any", count: current_flow.required_month_count)}",
          exact_text: true, normalize_ws: true)
      end
    end
  end

  context "when no activities are added for a renewal flow" do
    context "when required months equals reporting window" do
      let(:current_flow) do
        create(
          :activity_flow,
          reporting_window_type: "renewal",
          reporting_window_months: 6,
          volunteering_activities_count: 0,
          job_training_activities_count: 0,
          education_activities_count: 0
        )
      end

      before do
        session[:flow_id] = current_flow.id
        session[:flow_type] = :activity
        get :index
      end

      it "shows renewal months-required copy in the empty state" do
        expect(Capybara.string(response.body)).to have_selector("p",
          text: "#{I18n.t("activities.hub.months_required_label")} #{I18n.t("activities.hub.months_required_any", count: current_flow.required_month_count)}",
          exact_text: true, normalize_ws: true)
      end
    end

    context "when subset required months are configured" do
      let(:current_flow) do
        stub_client_agency_config_value("sandbox", "renewal_required_months", 3)
        create(
          :activity_flow,
          reporting_window_type: "renewal",
          reporting_window_months: 6,
          volunteering_activities_count: 0,
          job_training_activities_count: 0,
          education_activities_count: 0
        )
      end

      before do
        session[:flow_id] = current_flow.id
        session[:flow_type] = :activity
        get :index
      end

      it "shows the renewal 'any months' copy in the empty state" do
        expect(Capybara.string(response.body)).to have_selector("p",
          text: "#{I18n.t("activities.hub.months_required_label")} #{I18n.t("activities.hub.months_required_any", count: current_flow.required_month_count)}",
          exact_text: true, normalize_ws: true)
      end
    end
  end

  context "when renewal required-month override is passed in params" do
    let(:invitation) { create(:activity_flow_invitation, cbv_applicant: create(:cbv_applicant, :sandbox)) }

    before do
      allow(controller).to receive(:internal_environment?).and_return(true)
      get :index, params: {
        token: invitation.auth_token,
        reporting_window: "renewal",
        renewal_required_months: "2"
      }
    end

    it "persists the required-month override on the flow" do
      flow = ActivityFlow.find(session[:flow_id])

      expect(flow.renewal_required_months).to eq(2)
      expect(flow.required_month_count).to eq(2)
    end
  end

  context "when education activity has no enrollment records" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }

    before do
      create(:education_activity, activity_flow: current_flow, status: :no_enrollments)
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows education empty-state copy" do
      expect(response.body).to include(I18n.t("activities.hub.empty.education"))
    end
  end

  context "when education activity has enrollment records" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }
    let(:education_activity) { create(:education_activity, activity_flow: current_flow) }

    before do
      create(
        :nsc_enrollment_term,
        education_activity:,
        term_begin: current_flow.reporting_months.first.beginning_of_month,
        term_end: current_flow.reporting_months.first.end_of_month
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows only enrollment data and not the empty-state copy" do
      expect(response.body).to include("Test University")
      expect(response.body).to include(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.half_time")
        )
      )
      expect(response.body).not_to include(I18n.t("activities.hub.cards.hours", count: ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD))
      expect(response.body).not_to include(I18n.t("activities.hub.cards.credit_hours", amount: 12))
      expect(response.body).not_to include(I18n.t("activities.hub.empty.education"))
    end

    it "routes card edit to education review with from_edit" do
      expect(response.body).to include(
        review_activities_flow_education_path(id: education_activity.id, from_edit: 1)
      )
    end
  end

  context "when education activity has less-than-half-time enrollment records" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }
    let(:education_activity) { create(:education_activity, activity_flow: current_flow, data_source: :partially_self_attested) }

    before do
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education_activity,
        credit_hours: 4,
        term_begin: current_flow.reporting_months.first.beginning_of_month,
        term_end: current_flow.reporting_months.first.end_of_month
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows only enrollment status on the education card" do
      expect(response.body).to include("Test University")
      expect(response.body).to include(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.less_than_half_time")
        )
      )
      expect(response.body).not_to include(I18n.t("activities.hub.cards.credit_hours", amount: 4))
      expect(response.body).not_to include(I18n.t("activities.hub.cards.hours", count: 52))
      expect(response.body).not_to include(I18n.t("activities.hub.empty.education"))
    end

    it "routes card edit to education review with from_edit" do
      expect(response.body).to include(
        review_activities_flow_education_path(id: education_activity.id, from_edit: 1)
      )
    end
  end

  context "when partially self-attested education has multiple enrollments for the same school" do
    let(:current_flow) do
      create(
        :activity_flow,
        volunteering_activities_count: 0,
        job_training_activities_count: 0,
        education_activities_count: 0,
        reporting_window_months: 2
      )
    end

    before do
      education_activity = create(:education_activity, activity_flow: current_flow, data_source: :partially_self_attested)
      first_month = current_flow.reporting_months.first
      second_month = current_flow.reporting_months.second

      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education_activity,
        school_name: "River College",
        credit_hours: 3,
        term_begin: first_month,
        term_end: first_month.end_of_month
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education_activity,
        school_name: "River College",
        credit_hours: 5,
        term_begin: second_month,
        term_end: second_month.end_of_month
      )

      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "renders one card for the school with enrollment data for both months" do
      education_cards = Nokogiri::HTML.parse(response.body).css("[data-activity-type='education'] .activity-hub-card")

      expect(education_cards.length).to eq(1)
      expect(response.body).to include("River College")
      expect(response.body.scan(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.less_than_half_time")
        )
      ).length).to eq(2)
      expect(response.body).not_to include(I18n.t("activities.hub.cards.credit_hours", amount: 3))
      expect(response.body).not_to include(I18n.t("activities.hub.cards.credit_hours", amount: 5))
    end
  end

  context "when education activity has mixed overlapping statuses in each month" do
    let(:half_time_school_name) { "Pine Valley College" }
    let(:less_than_half_time_school_name) { "Riverside Community College" }

    let(:current_flow) do
      create(
        :activity_flow,
        volunteering_activities_count: 0,
        job_training_activities_count: 0,
        education_activities_count: 0,
        reporting_window_months: 2
      )
    end

    before do
      education_activity = create(:education_activity, activity_flow: current_flow, data_source: :validated, status: :succeeded)
      first_month = current_flow.reporting_months.first
      second_month = current_flow.reporting_months.second
      create(
        :nsc_enrollment_term,
        education_activity: education_activity,
        school_name: half_time_school_name,
        enrollment_status: :half_time,
        term_begin: first_month,
        term_end: second_month.end_of_month
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education_activity,
        school_name: less_than_half_time_school_name,
        credit_hours: 0,
        term_begin: first_month,
        term_end: second_month.end_of_month
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows only the qualifying enrollment on education cards" do
      expect(response.body).to include(half_time_school_name)
      expect(response.body).not_to include(less_than_half_time_school_name)
      expect(response.body).to include(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.half_time")
        )
      )
      expect(response.body).not_to include(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.less_than_half_time")
        )
      )
      expect(response.body).not_to include(I18n.t("activities.hub.cards.hours", count: ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD))
    end
  end

  context "when summer carryover applies for an education activity" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 2) }

    before do
      current_flow.shift_reporting_window_start!("2025-07-01")
      education_activity = create(:education_activity, activity_flow: current_flow, status: "succeeded")
      create(
        :nsc_enrollment_term,
        education_activity: education_activity,
        school_name: "Coastal State College",
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15)
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education_activity,
        school_name: "Coastal State College",
        term_begin: Date.new(2025, 7, 1),
        term_end: Date.new(2025, 8, 15)
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "renders one education card and shows the spring enrollment status" do
      education_section = Nokogiri::HTML.parse(response.body)
        .css("[data-activity-type='education'] .activity-hub-card")

      expect(education_section.length).to eq(1)
      expect(response.body).to include("Coastal State College")
      expect(response.body).to include(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.half_time")
        )
      )
      expect(response.body).not_to include(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.less_than_half_time")
        )
      )
    end
  end

  context "when summer carryover applies with no summer term" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 2) }

    before do
      current_flow.shift_reporting_window_start!("2025-07-01")
      education_activity = create(:education_activity, activity_flow: current_flow, status: "succeeded")
      create(
        :nsc_enrollment_term,
        education_activity: education_activity,
        school_name: "Coastal State College",
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15)
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "renders one education card and shows the spring enrollment status for the summer months" do
      education_section = Nokogiri::HTML.parse(response.body)
        .css("[data-activity-type='education'] .activity-hub-card")

      expect(education_section.length).to eq(1)
      expect(response.body.scan("Enrollment: Half-time").length).to eq(2)
      expect(response.body).not_to include("Enrollment: Not enrolled")
    end
  end

  context "when validated education terms overlap in the same reporting month" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 2) }

    before do
      current_flow.shift_reporting_window_start!("2025-06-01")
      education_activity = create(:education_activity, activity_flow: current_flow, status: "succeeded")
      create(
        :nsc_enrollment_term,
        education_activity: education_activity,
        school_name: "Test University",
        enrollment_status: "half_time",
        term_begin: Date.new(2025, 3, 1),
        term_end: Date.new(2025, 6, 15)
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education_activity,
        school_name: "Test University",
        term_begin: Date.new(2025, 6, 1),
        term_end: Date.new(2025, 7, 31)
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "renders one education card and shows the stronger overlapping enrollment status" do
      education_section = Nokogiri::HTML.parse(response.body)
        .css("[data-activity-type='education'] .activity-hub-card")

      expect(education_section.length).to eq(1)
      expect(response.body.scan("Enrollment: Half-time").length).to eq(2)
      expect(response.body).not_to include("Enrollment: Less than half-time")
    end
  end

  context "when self-attested education activity is added" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }
    let(:education_activity) do
      create(
        :education_activity,
        :with_self_attested_term,
        activity_flow: current_flow,
        school_name: "Colorado Springs Community College",
        credit_hours: 4
      )
    end

    before do
      education_activity
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows self-attested education card details and hides empty-state copy" do
      expect(response.body).to include("Colorado Springs Community College")
      expect(response.body).to include(I18n.t("activities.hub.cards.credit_hours", amount: 4))
      expect(response.body).to include(I18n.t("activities.hub.cards.hours", count: 52))
      expect(response.body).not_to include(I18n.t("activities.hub.empty.education"))
      expect(response.body).to include(I18n.t("activities.hub.review_and_submit"))
    end

    it "routes card edit to education review with from_edit" do
      expect(response.body).to include(
        review_activities_flow_education_path(id: education_activity.id, from_edit: 1)
      )
    end
  end

  context "when a self-attested education term is added" do
    let(:credit_hours) { 3.5 }
    let(:current_flow) do
      create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0,
        education_activities_count: 0, reporting_window_months: 2)
    end
    let(:education_activity) do
      create(:education_activity, activity_flow: current_flow, data_source: :fully_self_attested,
        school_name: "Test University", self_attested_term_start: current_flow.reporting_months.first,
        self_attested_term_end: current_flow.reporting_months.last,
        self_attested_enrollment_status: "less_than_half_time", credit_hours: credit_hours)
    end
    let(:rendered) { Capybara.string(response.body) }

    before do
      education_activity
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows the term's fractional credit hours" do
      expect(rendered).to have_selector("p", text: I18n.t("activities.hub.cards.credit_hours",
        amount: ApplicationHelper.format_decimal_amount(education_activity.credit_hours)), exact_text: true)
    end

    it "shows the term's community engagement hours" do
      expect(rendered).to have_selector("p", text: I18n.t("activities.hub.cards.hours",
        count: ApplicationHelper.format_decimal_amount(education_activity.community_engagement_hours(education_activity.credit_hours))), exact_text: true)
    end

    context "with whole-number credits" do
      let(:credit_hours) { 6 }

      it "formats the credit hours without insignificant zeros" do
        expect(rendered).to have_selector("p", text: I18n.t("activities.hub.cards.credit_hours",
          amount: ApplicationHelper.format_decimal_amount(education_activity.credit_hours)), exact_text: true)
      end

      it "formats the community engagement hours without insignificant zeros" do
        expect(rendered).to have_selector("p", text: I18n.t("activities.hub.cards.hours",
          count: ApplicationHelper.format_decimal_amount(education_activity.community_engagement_hours(education_activity.credit_hours))), exact_text: true)
      end
    end
  end

  context "when self-attested employment activities are added" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }

    before do
      employment_activity = create(:employment_activity, activity_flow: current_flow, employer_name: "Gainesville Wrecking")
      create(
        :employment_activity_month,
        employment_activity: employment_activity,
        month: current_flow.reporting_months.first.beginning_of_month,
        gross_income: 500,
        hours: 40
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows current flow employment activities" do
      expect(assigns(:employment_activities)).to match_array(current_flow.employment_activities)
      expect(response.body).to include("Gainesville Wrecking")
      expect(response.body).to include(I18n.t("activities.hub.cards.gross_income", amount: "$500.00"))
      expect(response.body).to include(I18n.t("activities.hub.cards.hours", count: 40))
    end
  end

  context "when the flow has no activities" do
    let(:current_flow) do
      create(
        :activity_flow,
        volunteering_activities_count: 0,
        job_training_activities_count: 0,
        education_activities_count: 0
      )
    end

    before do
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "renders all agency-enabled activity type sections" do
      rendered = Capybara.string(response.body)

      expect(rendered).to have_css("[data-activity-type='employment']")
      expect(rendered).to have_css("[data-activity-type='education']")
      expect(rendered).to have_css("[data-activity-type='community_service']")
      expect(rendered).to have_css("[data-activity-type='work_programs']")
    end
  end

  context "when the flow is employment-focused" do
    let(:current_flow) do
      create(
        :activity_flow,
        employment_focused: true,
        volunteering_activities_count: 0,
        job_training_activities_count: 0,
        education_activities_count: 0
      )
    end

    before do
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
    end

    context "with no activities added" do
      before { get :index }

      it "redirects to the add-your-work page instead of rendering the review page" do
        expect(response).to redirect_to(activities_flow_income_add_your_work_path)
      end

      it "does not track a hub-viewed event" do
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)

        expect(EventTrackingJob).not_to receive(:perform_later).with("HubViewed", anything, anything)
        get :index
      end
    end

    # Builds a real (unmocked) Aggregators::AggregatorReports::AggregatorReport
    # populated with the given employment/income/paystub data, and stubs
    # AggregatorReportFetcher to return it for the current flow. Using a real
    # report (rather than a method-by-method double) exercises the actual
    # find_account_report/summarize_by_month logic the view depends on.
    def stub_aggregator_report_for(payroll_account, employment_type:, employment_status: "employed", pay_frequency: "biweekly", compensation_amount: 25_00, compensation_unit: "hourly", paystubs: [], gigs: [])
      employment = Aggregators::ResponseObjects::Employment.new(
        account_id: payroll_account.aggregator_account_id,
        employer_name: "Acme Employer",
        employment_type: employment_type,
        start_date: "2024-01-01",
        termination_date: nil,
        status: employment_status
      )
      income = Aggregators::ResponseObjects::Income.new(
        account_id: payroll_account.aggregator_account_id,
        pay_frequency: pay_frequency,
        compensation_amount: compensation_amount,
        compensation_unit: compensation_unit
      )
      report = Aggregators::AggregatorReports::AggregatorReport.new(
        payroll_accounts: [ payroll_account ],
        reporting_date_range: current_flow.reporting_window_range
      )
      report.employments = [ employment ]
      report.incomes = [ income ]
      report.paystubs = paystubs
      report.gigs = gigs
      report.identities = []
      report.has_fetched = true

      allow(AggregatorReportFetcher).to receive(:new)
        .with(current_flow)
        .and_return(instance_double(AggregatorReportFetcher, report: report))
    end

    context "with a self-attested employment activity" do
      let(:reporting_month) { current_flow.reporting_months.first.beginning_of_month }
      let!(:employment_activity) { create(:employment_activity, activity_flow: current_flow) }

      before do
        create(:employment_activity_month, employment_activity: employment_activity, month: reporting_month, hours: 15, gross_income: 450)
        get :index
      end

      it "renders the employment-focused review template" do
        expect(response).to render_template(:employment_focused_review)
      end

      it "renders the job heading and employer information section" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_text(
          I18n.t("activities.activities.employment_focused_review.employment_header", count: 1, employer_name: "Gainesville Wrecking")
        )
        expect(rendered).to have_text(I18n.t("activities.activities.employment_focused_review.employer_information"))
        expect(rendered).to have_text("Gainesville Wrecking")
        expect(rendered).to have_text("942 W Harlan Ave, Gainesville, FL 32611")
        expect(rendered).to have_text("Donny Spears")
        expect(rendered).to have_text("donny@gainesvillewrecking.com")
        expect(rendered).to have_text("(415) 344-8009")
      end

      it "renders the hours and income section with monthly data" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_text(I18n.t("activities.activities.employment_focused_review.hours_and_income"))
        expect(rendered).to have_text(I18n.l(reporting_month, format: :month_year))
        expect(rendered).to have_text("$450.00")
        expect(rendered).to have_text("15")
      end

      it "renders the consent checkbox and submit button" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_css("input[type='checkbox'][name='activity_flow[consent_to_submit]']")
        expect(rendered).to have_button(
          I18n.t("activities.activities.employment_focused_review.submit", agency_name: I18n.t("shared.agency_full_name.sandbox"))
        )
      end

      it "does not render a document upload section when no documents are attached" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_no_text(I18n.t("activities.document_uploads.remove_file"))
      end

      it "does not render an additional comments section when none is present" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_no_text(I18n.t("activities.activities.employment_focused_review.additional_comments"))
      end

      context "with additional comments" do
        before do
          employment_activity.update!(additional_comments: "I was paid late this month.")
          get :index
        end

        it "renders the additional comments section" do
          rendered = Capybara.string(response.body)

          expect(rendered).to have_text(I18n.t("activities.activities.employment_focused_review.additional_comments"))
          expect(rendered).to have_text("I was paid late this month.")
        end
      end

      context "with an uploaded document" do
        before do
          employment_activity.document_uploads.attach(
            io: StringIO.new("synthetic document"),
            filename: "Paystub.pdf",
            content_type: "application/pdf"
          )
          get :index
        end

        it "renders the uploaded document with a working remove link" do
          rendered = Capybara.string(response.body)

          expect(rendered).to have_text("Paystub.pdf")
          expect(rendered).to have_css(
            "a[href='#{
              activities_flow_income_employment_document_upload_path(
                employment_id: employment_activity, id: employment_activity.document_uploads.first
              )
            }']"
          )
        end
      end

      context "with a second self-attested job" do
        let!(:second_employment_activity) { create(:employment_activity, activity_flow: current_flow, employer_name: "Beta Staffing") }

        before do
          create(:employment_activity_month, employment_activity: second_employment_activity, month: reporting_month, hours: 20, gross_income: 300)
          get :index
        end

        it "numbers each job heading sequentially, newest job first" do
          rendered = Capybara.string(response.body)

          expect(rendered).to have_text(
            I18n.t("activities.activities.employment_focused_review.employment_header", count: 1, employer_name: "Beta Staffing")
          )
          expect(rendered).to have_text(
            I18n.t("activities.activities.employment_focused_review.employment_header", count: 2, employer_name: "Gainesville Wrecking")
          )
        end
      end
    end

    context "with a synced w2 payroll account" do
      let(:latest_month) { current_flow.reporting_months.max }
      let!(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: current_flow, aggregator_account_id: "acct-123") }

      before do
        paystub = Aggregators::ResponseObjects::Paystub.new(
          account_id: payroll_account.aggregator_account_id,
          gross_pay_amount: 222_22,
          pay_date: latest_month.to_s,
          hours: 35.0,
          earnings: [],
          deductions: []
        )
        stub_aggregator_report_for(payroll_account, employment_type: :w2, paystubs: [ paystub ])

        get :index
      end

      it "renders the employment-focused review template" do
        expect(response).to render_template(:employment_focused_review)
      end

      it "renders the job heading and employment details table" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_text(
          I18n.t("activities.activities.employment_focused_review.employment_header", count: 1, employer_name: "Acme Employer")
        )
        expect(rendered).to have_text(I18n.t("activities.activities.employment_focused_review.employment_details"))
        expect(rendered).to have_text(I18n.l(Date.parse("2024-01-01"), format: :long))
        expect(rendered).to have_text("Employed")
        expect(rendered).to have_text("Bi-weekly")
        expect(rendered).to have_text("$25.00")
      end

      it "renders the monthly details table with month, gross income, number of paychecks, and hours worked" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_text(I18n.t("activities.activities.employment_focused_review.monthly_details"))
        expect(rendered).to have_text(I18n.t("components.report.monthly_summary_table.w2.title_number_of_paychecks"))
        expect(rendered).to have_text(I18n.t("components.report.monthly_summary_table.activity.hours_worked"))
        expect(rendered).to have_text(I18n.l(latest_month.beginning_of_month, format: :month_year))
        expect(rendered).to have_text("$222.22")
        expect(rendered).to have_text("35")
      end

      it "does not render an additional comments section when none is present" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_no_text(I18n.t("activities.activities.employment_focused_review.additional_comments"))
      end

      context "with additional comments" do
        before do
          payroll_account.update!(additional_information: "I switched employers mid-month.")
          get :index
        end

        it "renders the additional comments section" do
          rendered = Capybara.string(response.body)

          expect(rendered).to have_text(I18n.t("activities.activities.employment_focused_review.additional_comments"))
          expect(rendered).to have_text("I switched employers mid-month.")
        end
      end
    end

    context "with a synced gig payroll account" do
      let(:latest_month) { current_flow.reporting_months.max }
      let!(:payroll_account) { create(:payroll_account, :argyle_fully_synced, flow: current_flow, aggregator_account_id: "acct-456") }

      before do
        gig = Aggregators::ResponseObjects::Gig.new(
          account_id: payroll_account.aggregator_account_id,
          gig_type: "rideshare",
          hours: 20.0,
          start_date: latest_month.to_s,
          end_date: latest_month.to_s,
          compensation_amount: 15_000
        )
        stub_aggregator_report_for(payroll_account, employment_type: :gig, gigs: [ gig ])

        get :index
      end

      it "renders the gig monthly summary table with the employment-focused hours label" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_text(I18n.t("activities.activities.employment_focused_review.monthly_details"))
        # On the employment-focused review page, gig hours use the same
        # employment-focused label as the W2 table (GigMonthlySummaryTableComponent#hours_header
        # mirrors W2MonthlySummaryTableComponent#hours_header).
        expect(rendered).to have_text(I18n.t("components.report.monthly_summary_table.activity.hours_worked"))
        expect(rendered).not_to have_text(I18n.t("components.report.monthly_summary_table.activity.community_engagement_hours"))
        expect(rendered).to have_text(I18n.l(latest_month.beginning_of_month, format: :month_year))
        expect(rendered).to have_text("20")
      end
    end

    context "with both a synced payroll account and a self-attested job" do
      let!(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: current_flow, aggregator_account_id: "acct-123") }
      let!(:employment_activity) { create(:employment_activity, activity_flow: current_flow, employer_name: "Beta Staffing") }

      before do
        stub_aggregator_report_for(payroll_account, employment_type: :w2, paystubs: [])
        create(:employment_activity_month, employment_activity: employment_activity, month: current_flow.reporting_months.first.beginning_of_month, hours: 10, gross_income: 100)

        get :index
      end

      it "numbers the payroll job first and the self-attested job second" do
        rendered = Capybara.string(response.body)

        expect(rendered).to have_text(
          I18n.t("activities.activities.employment_focused_review.employment_header", count: 1, employer_name: "Acme Employer")
        )
        expect(rendered).to have_text(
          I18n.t("activities.activities.employment_focused_review.employment_header", count: 2, employer_name: "Beta Staffing")
        )
      end
    end
  end
end

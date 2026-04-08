require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  include_context "activity_hub"
  render_views

  describe "#index" do
    let(:current_flow) { create(:activity_flow) }

    before do
      create(:activity_flow) # ensure there is a second flow that might get mixed up
      current_flow.reload
      activity = create(:volunteering_activity, activity_flow: current_flow, organization_name: "Food Pantry")
      create(:volunteering_activity_month, volunteering_activity: activity, month: current_flow.reporting_window_range.begin, hours: 5)

      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
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

    it "renders the progress indicator when hours exist" do
      expect(response.body).to include("activity-flow-progress-indicator")
    end

    it "shows in progress hub heading and description" do
      expect(response.body).to include(I18n.t("activities.hub.in_progress_state_title"))
      expect(response.body).to include(
        I18n.t(
          "activities.hub.in_progress_state_description",
          agency_name: "Test Agency"
        )
      )
    end

    it "does not render progress indicator description copy for application variant" do
      expect(response.body).not_to include("activity-flow-progress-indicator__description")
    end

    it "uses months completed in the indicator title for multi-month application progress" do
      rendered = Capybara.string(response.body)
      indicator_title = rendered.find(".activity-flow-progress-indicator__title").text.squish

      expect(indicator_title).to eq("0/2 months completed")
      expect(rendered).not_to have_css(".activity-flow-progress-indicator__months-completed")
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

    it "does not render the progress indicator" do
      expect(response.body).not_to include("activity-flow-progress-indicator")
    end

    it "shows empty-state hub heading and description" do
      page_text = Capybara.string(response.body).text

      expect(page_text).to include(I18n.t("activities.hub.empty_state_title"))
      expect(page_text).to include(I18n.t("activities.hub.empty_state_reporting_period_label"))
      expect(page_text).to include(current_flow.reporting_window_display)
      expect(page_text).to include(
        I18n.t(
          "activities.hub.empty_state_description",
          reporting_window: current_flow.reporting_window_display
        )
      )
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

    it "shows the verification info link in the in-progress state" do
      page_text = Capybara.string(response.body).text
      expect(page_text).to include(I18n.t("activities.hub.verification_info_link"))
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

    it "shows completed hub heading and description and hides the verification info link" do
      page_text = Capybara.string(response.body).text

      expect(page_text).to include(I18n.t("activities.hub.completed_state_title"))
      expect(page_text).to include(
        I18n.t(
          "activities.hub.completed_state_description",
          agency_name: "Test Agency"
        )
      )
      expect(page_text).not_to include(I18n.t("activities.hub.verification_info_link"))
    end

    it "keeps single-month application indicator title in month-progress format" do
      rendered = Capybara.string(response.body)
      indicator_title = rendered.find(".activity-flow-progress-indicator__title").text.squish

      expected_month = I18n.l(current_flow.reporting_window_range.begin, format: :month)
      expect(indicator_title).to eq(I18n.t("activity_flow_progress_indicator.title", month: expected_month))
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

    it "keeps the hub in in-progress state to match the progress indicator completion rule" do
      expect(response.body).to include(I18n.t("activities.hub.in_progress_state_title"))
      expect(response.body).not_to include(I18n.t("activities.hub.completed_state_title"))
    end
  end

  context "when activities are added for a renewal flow" do
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
      activity = create(:volunteering_activity, activity_flow: current_flow)
      create(
        :volunteering_activity_month,
        volunteering_activity: activity,
        month: current_flow.reporting_window_range.begin,
        hours: 20
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "does not render renewal subtitle when required months equals reporting window" do
      expect(response.body).not_to include("activity-flow-progress-indicator__description")
    end
  end

  context "when no activities are added for a renewal flow" do
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
      page_text = Capybara.string(response.body).text

      expect(page_text).to include(I18n.t("activities.hub.empty_state_months_required_label"))
      expect(page_text).to include(
        I18n.t("activities.hub.empty_state_months_required_all", required_month_count: 6)
      )
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

    it "shows enrollment data and not the empty-state copy" do
      expect(response.body).to include("Test University")
      expect(response.body).to include(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.half_time")
        )
      )
      expect(response.body).to include(I18n.t("activities.hub.cards.hours", count: ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD))
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

    it "shows enrollment status with saved credit hours and CE hours on the education card" do
      expect(response.body).to include("Test University")
      expect(response.body).to include(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.less_than_half_time")
        )
      )
      expect(response.body).to include(I18n.t("activities.hub.cards.credit_hours", amount: 4))
      expect(response.body).to include(I18n.t("activities.hub.cards.hours", count: 16))
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

    it "renders one card for the school with both months of data" do
      education_cards = Nokogiri::HTML.parse(response.body).css("[data-activity-type='education'] .activity-hub-card")

      expect(education_cards.length).to eq(1)
      expect(response.body).to include("River College")
      expect(response.body).to include(I18n.t("activities.hub.cards.credit_hours", amount: 3))
      expect(response.body).to include(I18n.t("activities.hub.cards.credit_hours", amount: 5))
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

    it "shows all enrollment statuses on education cards and uses 80 hours in monthly progress" do
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
      progress_text = /80\s*\/\s*#{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD}\s*#{I18n.t("activity_flow_progress_indicator.hours")}/
      page_text = Capybara.string(response.body).text
      expect(page_text.scan(progress_text).count).to eq(2)
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
        activity_flow: current_flow,
        data_source: :fully_self_attested,
        school_name: "Colorado Springs Community College"
      )
    end

    before do
      create(
        :education_activity_month,
        education_activity: education_activity,
        month: current_flow.reporting_months.first.beginning_of_month,
        hours: 4
      )
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
      get :index
    end

    it "shows self-attested education card details and hides empty-state copy" do
      expect(response.body).to include("Colorado Springs Community College")
      expect(response.body).to include(I18n.t("activities.hub.cards.credit_hours", amount: 4))
      expect(response.body).to include(I18n.t("activities.hub.cards.hours", count: 16))
      expect(response.body).not_to include(I18n.t("activities.hub.empty.education"))
      expect(response.body).to include(I18n.t("activities.hub.review_and_submit"))
    end

    it "routes card edit to education review with from_edit" do
      expect(response.body).to include(
        review_activities_flow_education_path(id: education_activity.id, from_edit: 1)
      )
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
end

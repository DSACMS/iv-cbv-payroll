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
  end

  describe "delete-on-close cleanup" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }

    before do
      session[:flow_id] = current_flow.id
      session[:flow_type] = :activity
    end

    it "destroys the tracked incomplete activity on hub visit" do
      activity = create(:volunteering_activity, activity_flow: current_flow)
      session[:creating_activity] = { "class_name" => "VolunteeringActivity", "id" => activity.id }

      expect { get :index }.to change(VolunteeringActivity, :count).by(-1)
      expect(session[:creating_activity]).to be_nil
    end

    it "does nothing when no creating_activity is in session" do
      create(:volunteering_activity, activity_flow: current_flow)

      expect { get :index }.not_to change(VolunteeringActivity, :count)
    end

    it "handles an already-deleted activity gracefully" do
      session[:creating_activity] = { "class_name" => "VolunteeringActivity", "id" => -1 }

      expect { get :index }.not_to raise_error
      expect(session[:creating_activity]).to be_nil
    end

    it "destroys a tracked incomplete payroll account on hub visit" do
      payroll_account = create(:payroll_account, :pinwheel_fully_synced, flow: current_flow)
      session[:creating_payroll_account] = payroll_account.aggregator_account_id

      expect { get :index }.to change(current_flow.payroll_accounts, :count).by(-1)
      expect(session[:creating_payroll_account]).to be_nil
    end

    it "handles an already-deleted payroll account gracefully" do
      session[:creating_payroll_account] = "nonexistent-account-id"

      expect { get :index }.not_to raise_error
      expect(session[:creating_payroll_account]).to be_nil
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

    it "renders the progress indicator even with no hours" do
      expect(response.body).to include("activity-flow-progress-indicator")
    end

    it "renders the two-column container" do
      expect(response.body).to include("activity-hub-columns")
    end

    it "does not render the horizontal divider" do
      expect(response.body).not_to include("activity-hub-divider")
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

    before do
      education_activity = create(:education_activity, activity_flow: current_flow)
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
  end

  context "when education activity has less-than-half-time enrollment records" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }

    before do
      education_activity = create(:education_activity, activity_flow: current_flow, data_source: :partially_self_attested)
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
      expect(response.body).to include(less_than_half_time_school_name)
      expect(response.body).to include(
        I18n.t(
          "activities.hub.cards.enrollment_status",
          status: I18n.t("components.enrollment_term_table_component.status.half_time")
        )
      )
      expect(response.body).to include(
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

  context "when self-attested education activity is added" do
    let(:current_flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0, reporting_window_months: 1) }

    before do
      education_activity = create(
        :education_activity,
        activity_flow: current_flow,
        data_source: :fully_self_attested,
        school_name: "Colorado Springs Community College"
      )
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

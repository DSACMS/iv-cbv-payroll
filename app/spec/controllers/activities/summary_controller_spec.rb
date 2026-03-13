require "rails_helper"

RSpec.describe Activities::SummaryController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) {
    create(
      :activity_flow,
      job_training_activities_count: 0,
      volunteering_activities_count: 0,
      education_activities_count: 0
    )
  }
  let(:other_flow) { create(:activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #show" do
    it "only shows activities belonging to the current activity flow" do
      visible_volunteering = create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Scoped", hours: 1)
      create(:volunteering_activity, activity_flow: other_flow, organization_name: "Ignored", hours: 2)
      visible_job_training = create(:job_training_activity, activity_flow: activity_flow, program_name: "Resume Workshop", organization_address: "123 Main St", hours: 6)
      create(:job_training_activity, activity_flow: other_flow, program_name: "Other Workshop", organization_address: "456 Elm St", hours: 8)

      get :show

      expect(assigns(:community_service_activities)).to contain_exactly(visible_volunteering)
      expect(assigns(:work_programs_activities)).to contain_exactly(visible_job_training)
      expect(response.body).to include("Scoped")
      expect(response.body).to include("Resume Workshop")
    end

    it "builds all_activities list with all activity types" do
      create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Org A", hours: 1)
      create(:job_training_activity, activity_flow: activity_flow, program_name: "Program B", organization_address: "123 Main St", hours: 6)
      education_activity = create(:education_activity, activity_flow: activity_flow, status: :succeeded)
      create(:nsc_enrollment_term, education_activity: education_activity, school_name: "Test University")

      get :show

      all_activities = assigns(:all_activities)
      expect(all_activities.length).to eq(3)
      expect(all_activities.map { |a| a[:type] }).to contain_exactly(:community_service, :work_programs, :education)
    end

    it "excludes validated education activities with no enrollment terms from all_activities" do
      create(:education_activity, activity_flow: activity_flow, status: :no_enrollments)
      self_attested_activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :self_attested,
        school_name: "University of Illinois"
      )
      create(:education_activity_month, education_activity: self_attested_activity, month: activity_flow.reporting_months.first, hours: 6)

      get :show

      education_activities = assigns(:all_activities).select { |activity| activity[:type] == :education }
      expect(education_activities.size).to eq(1)
      expect(education_activities.first[:activity]).to eq(self_attested_activity)
    end

    it "renders community service organization details and monthly hours in the summary table" do
      activity_flow.update!(reporting_window_months: 2)

      activity = create(
        :volunteering_activity,
        activity_flow: activity_flow,
        organization_name: "Habitat for Humanity",
        street_address: "942 W Harlan Ave",
        city: "Gainesville",
        state: "Florida",
        zip_code: "32601",
        coordinator_name: "Donny Murphy",
        coordinator_email: "donny@habitat.com"
      )
      first_month = create(:volunteering_activity_month, volunteering_activity: activity, month: activity_flow.reporting_months.first, hours: 45)
      second_month = create(:volunteering_activity_month, volunteering_activity: activity, month: activity_flow.reporting_months.second, hours: 12)

      get :show

      expect(response.body).to include(activity.organization_name)
      expect(response.body).to include(activity.formatted_address)
      expect(response.body).to include(activity.coordinator_name)
      expect(response.body).to include(activity.coordinator_email)
      expect(response.body).to include(I18n.t("shared.not_applicable"))
      expect(response.body).to include(I18n.l(first_month.month, format: :month))
      expect(response.body).to include(I18n.l(second_month.month, format: :month))
      expect(response.body).to include(first_month.hours.to_s)
      expect(response.body).to include(second_month.hours.to_s)
    end

    it "renders work program details and monthly hours in the summary table" do
      activity_flow.update!(reporting_window_months: 2)

      activity = create(
        :job_training_activity,
        activity_flow: activity_flow,
        organization_name: "Habitat for Humanity",
        program_name: "Resume and Skills Program",
        street_address: "942 W Harlan Ave",
        city: "Gainesville",
        state: "Florida",
        zip_code: "32601",
        contact_name: "Donny Murphy",
        contact_email: "donny@habitat.com",
        contact_phone_number: "555-0100"
      )
      first_month = create(:job_training_activity_month, job_training_activity: activity, month: activity_flow.reporting_months.first, hours: 45)
      second_month = create(:job_training_activity_month, job_training_activity: activity, month: activity_flow.reporting_months.second, hours: 12)

      get :show

      expect(response.body).to include(activity.organization_name)
      expect(response.body).to include(activity.program_name)
      expect(response.body).to include(activity.formatted_address)
      expect(response.body).to include(activity.contact_name)
      expect(response.body).to include(activity.contact_email)
      expect(response.body).to include(activity.contact_phone_number)
      expect(response.body).to include(I18n.l(first_month.month, format: :month))
      expect(response.body).to include(I18n.l(second_month.month, format: :month))
      expect(response.body).to include(first_month.hours.to_s)
      expect(response.body).to include(second_month.hours.to_s)
    end

    it "renders self-attested education details and monthly credit hours in the summary table" do
      activity_flow.update!(reporting_window_months: 2)

      activity = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :self_attested,
        school_name: "University of Illinois",
        street_address: "601 E John St",
        city: "Champaign",
        state: "IL",
        contact_name: "Dr. Smith",
        contact_email: "smith@illinois.edu",
        contact_phone_number: "555-1212"
      )
      first_month = create(:education_activity_month, education_activity: activity, month: activity_flow.reporting_months.first, hours: 4)
      second_month = create(:education_activity_month, education_activity: activity, month: activity_flow.reporting_months.second, hours: 6)

      get :show

      expect(response.body).to include(activity.school_name)
      expect(response.body).to include(activity.formatted_address)
      expect(response.body).to include(activity.contact_name)
      expect(response.body).to include(activity.contact_email)
      expect(response.body).to include(activity.contact_phone_number)
      expect(response.body).to include(I18n.l(first_month.month, format: :month))
      expect(response.body).to include(I18n.l(second_month.month, format: :month))
      expect(response.body).to include(first_month.hours.to_s)
      expect(response.body).to include(second_month.hours.to_s)
    end

    context "with payroll accounts" do
      it "includes synced payroll accounts in all_activities list" do
        payroll_account = create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow)
        activity_flow.reporting_months.each do |month|
          create(:activity_flow_monthly_summary, activity_flow: activity_flow, payroll_account: payroll_account, month: month.beginning_of_month)
        end

        get :show

        all_activities = assigns(:all_activities)
        income_activity = all_activities.find { |a| a[:type] == :employment }
        expect(income_activity).to be_present
        expect(income_activity[:payroll_account]).to eq(payroll_account)
      end

      it "excludes unsynced payroll accounts from all_activities list" do
        create(:payroll_account, flow: activity_flow, synchronization_status: :in_progress)

        get :show

        all_activities = assigns(:all_activities)
        income_activity = all_activities.find { |a| a[:type] == :employment }
        expect(income_activity).to be_nil
      end

      it "renders persisted income summaries in the response" do
        payroll_account = create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow, aggregator_account_id: "acct-123")
        latest_month = activity_flow.reporting_months.max
        activity_flow.reporting_months.each do |month|
          create(
            :activity_flow_monthly_summary,
            activity_flow: activity_flow,
            payroll_account: payroll_account,
            month: month.beginning_of_month,
            employer_name: "Acme Employer",
            employment_type: "w2",
            total_w2_hours: (month == latest_month ? 40.0 : 0.0),
            accrued_gross_earnings_cents: (month == latest_month ? 123_45 : 0),
            paychecks_count: (month == latest_month ? 2 : 0)
          )
        end

        get :show

        expect(response.body).to include("Acme Employer")
        expect(response.body).to include("$123.45")
      end

      it "renders successfully when no summaries are persisted" do
        create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow, aggregator_account_id: "acct-123")
        allow(AggregatorReportFetcher).to receive(:new).with(activity_flow).and_return(double(report: nil))

        get :show

        expect(response).to have_http_status(:ok)
      end
    end

    it "renders the legal agreement checkbox" do
      get :show

      expect(response.body).to include(I18n.t("activities.summary.legal_agreement"))
    end

    it "renders the submit button with agency name" do
      get :show

      expect(response.body).to include("Submit to")
    end

    it "renders a back link pointing to the activity hub" do
      get :show

      expect(response.body).to include("back-nav")
      expect(response.body).to have_link(href: activities_flow_root_path)
    end
  end
end

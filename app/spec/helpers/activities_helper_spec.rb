require "rails_helper"

RSpec.describe ActivitiesHelper do
  describe "#community_service_cards" do
    let(:flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }
    let(:first_month) { flow.reporting_window_range.begin.beginning_of_month }

    context "with community service activities" do
      it "returns one card per activity" do
        activity_1 = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        activity_2 = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity_1, month: first_month, hours: 5)
        create(:volunteering_activity_month, volunteering_activity: activity_2, month: first_month + 1.month, hours: 10)

        result = helper.community_service_cards(flow.volunteering_activities)

        expect(result.length).to eq(2)
        expect(result.map { |c| c[:name] }).to all(eq("Food Pantry"))
      end

      it "includes the activity's name and hours" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 5)

        result = helper.community_service_cards(flow.volunteering_activities)

        expect(result.first[:name]).to eq("Food Pantry")
        expect(result.first[:months].first[:hours]).to eq(5)
        expect(result.first[:months].first[:month]).to eq(first_month)
      end

      it "includes edit path to community service edit" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 5)

        result = helper.community_service_cards(flow.volunteering_activities)

        expect(result.first[:edit_path]).to eq(
          helper.edit_activities_flow_community_service_path(id: activity.id)
        )
      end

      it "returns empty array for empty input" do
        result = helper.community_service_cards([])

        expect(result).to eq([])
      end

      it "returns empty months for activities with no monthly entries" do
        create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")

        result = helper.community_service_cards(flow.volunteering_activities.reload)

        expect(result.first[:months]).to be_empty
      end
    end
  end

  describe "#work_program_cards" do
    let(:flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }
    let(:first_month) { flow.reporting_months.first.beginning_of_month }

    it "uses program_name as card name" do
      activity = create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main")
      create(:job_training_activity_month, job_training_activity: activity, month: first_month, hours: 5)

      result = helper.work_program_cards(flow.job_training_activities)

      expect(result.first[:name]).to eq("Career Prep")
      expect(result.first[:months].first[:hours]).to eq(5)
      expect(result.first[:months].first[:month]).to eq(first_month)
    end

    it "returns one card per activity even with same program name" do
      activity_1 = create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main")
      activity_2 = create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main")
      create(:job_training_activity_month, job_training_activity: activity_1, month: first_month, hours: 5)
      create(:job_training_activity_month, job_training_activity: activity_2, month: first_month + 1.month, hours: 8)

      result = helper.work_program_cards(flow.job_training_activities)

      expect(result.length).to eq(2)
    end

    it "includes edit path to job training edit" do
      activity = create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main")
      create(:job_training_activity_month, job_training_activity: activity, month: first_month, hours: 5)

      result = helper.work_program_cards(flow.job_training_activities)

      expect(result.first[:edit_path]).to eq(
        helper.edit_activities_flow_job_training_path(id: activity.id)
      )
    end
  end

  describe "#education_cards" do
    let(:flow) { create(:activity_flow, reporting_window_months: 2, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }
    let(:first_month) { flow.reporting_window_range.begin }
    let(:second_month) { first_month + 1.month }
    let(:reporting_months) { [ first_month, second_month ] }

    it "uses school name from enrollment term as card title" do
      activity = create(:education_activity, activity_flow: flow, credit_hours: 12)
      create(:nsc_enrollment_term, education_activity: activity, school_name: "STATE UNIVERSITY", term_begin: first_month, term_end: second_month.end_of_month)

      result = helper.education_cards([ activity.reload ], reporting_months)

      expect(result.first[:name]).to eq("State University")
    end

    it "returns empty array when activity has no enrollment terms" do
      activity = create(:education_activity, activity_flow: flow, credit_hours: 12)

      result = helper.education_cards([ activity ], reporting_months)

      expect(result).to eq([])
    end

    it "shows enrollment status for months with overlapping terms" do
      activity = create(:education_activity, activity_flow: flow, credit_hours: 15)
      create(:nsc_enrollment_term, education_activity: activity, school_name: "Test U", enrollment_status: "full_time", term_begin: first_month, term_end: second_month.end_of_month)

      result = helper.education_cards([ activity.reload ], reporting_months)

      result.first[:months].each do |month_data|
        expect(month_data[:enrollment_status]).to eq("Full-time")
        expect(month_data[:credit_hours]).to eq(15)
      end
    end

    it "shows 'Not enrolled' for months without overlapping terms" do
      activity = create(:education_activity, activity_flow: flow, credit_hours: 12)
      create(:nsc_enrollment_term, education_activity: activity, school_name: "Test U", enrollment_status: "half_time", term_begin: first_month, term_end: first_month.end_of_month)

      result = helper.education_cards([ activity.reload ], reporting_months)

      # Months are in reverse order, so second_month is first
      second_month_data = result.first[:months].find { |m| m[:month] == second_month }
      first_month_data = result.first[:months].find { |m| m[:month] == first_month }

      expect(first_month_data[:enrollment_status]).to eq("Half-time")
      expect(first_month_data[:credit_hours]).to eq(12)
      expect(second_month_data[:enrollment_status]).to eq("Not enrolled")
      expect(second_month_data[:credit_hours]).to eq(0)
    end

    it "returns months in reverse chronological order" do
      activity = create(:education_activity, activity_flow: flow, credit_hours: 12)
      create(:nsc_enrollment_term, education_activity: activity, school_name: "Test U", term_begin: first_month, term_end: second_month.end_of_month)

      result = helper.education_cards([ activity.reload ], reporting_months)

      months = result.first[:months].map { |m| m[:month] }
      expect(months).to eq(months.sort.reverse)
    end

    it "includes edit path to education edit" do
      activity = create(:education_activity, activity_flow: flow, credit_hours: 12)
      create(:nsc_enrollment_term, education_activity: activity, school_name: "Test U", term_begin: first_month, term_end: second_month.end_of_month)

      result = helper.education_cards([ activity.reload ], reporting_months)

      expect(result.first[:edit_path]).to eq(
        helper.edit_activities_flow_education_path(id: activity.id)
      )
    end
  end

  describe "#employment_cards" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }
    let(:reporting_range) { flow.reporting_window_range }
    let(:first_month) { reporting_range.begin }
    let(:month_key) { first_month.strftime("%Y-%m") }
    let(:account_id) { "test-account-123" }

    let(:mock_employment) { double(employer_name: "ACME Corp") }
    let(:mock_account_report) { double(employment: mock_employment) }
    let(:mock_report) do
      instance_double(Aggregators::AggregatorReports::AggregatorReport).tap do |report|
        allow(report).to receive(:find_account_report).with(account_id).and_return(mock_account_report)
        allow(report).to receive(:summarize_by_month).and_return({
          account_id => {
            month_key => { accrued_gross_earnings: 2500_00, total_w2_hours: 80.0, total_gig_hours: 5.0 }
          }
        })
      end
    end

    let(:payroll_account) { build(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: account_id) }

    it "returns employer name from aggregator report" do
      result = helper.employment_cards([ payroll_account ], mock_report, reporting_range)

      expect(result.first[:name]).to eq("ACME Corp")
    end

    it "includes edit path to payment details" do
      result = helper.employment_cards([ payroll_account ], mock_report, reporting_range)

      expect(result.first[:edit_path]).to eq(
        helper.activities_flow_income_payment_details_path(user: { account_id: account_id })
      )
    end

    it "returns monthly gross earnings in cents and combined hours" do
      result = helper.employment_cards([ payroll_account ], mock_report, reporting_range)

      month_data = result.first[:months].first
      expect(month_data[:gross_earnings]).to eq(2500_00)
      expect(month_data[:hours]).to eq(85)
    end

    it "returns empty array when aggregator report is nil" do
      result = helper.employment_cards([ payroll_account ], nil, reporting_range)

      expect(result).to eq([])
    end

    it "falls back to N/A when employer name is unavailable" do
      allow(mock_report).to receive(:find_account_report).with(account_id).and_return(nil)

      result = helper.employment_cards([ payroll_account ], mock_report, reporting_range)

      expect(result.first[:name]).to eq(I18n.t("activities.employment.title"))
    end

    it "handles accounts with no monthly data" do
      allow(mock_report).to receive(:summarize_by_month).and_return({})

      result = helper.employment_cards([ payroll_account ], mock_report, reporting_range)

      expect(result.first[:months]).to be_empty
    end
  end

  describe "#employment_activity_cards" do
    let(:flow) { create(:activity_flow, reporting_window_months: 2, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }
    let(:activity) { create(:employment_activity, activity_flow: flow, employer_name: "Gainesville Wrecking") }
    let(:first_month) { flow.reporting_months.first.beginning_of_month }
    let(:second_month) { flow.reporting_months.second.beginning_of_month }

    before do
      create(:employment_activity_month, employment_activity: activity, month: first_month, gross_income: 500, hours: 40)
      create(:employment_activity_month, employment_activity: activity, month: second_month, gross_income: 300, hours: 20)
    end

    it "returns card data with employer name, month entries, and edit path" do
      result = helper.employment_activity_cards([ activity ])

      expect(result.first[:name]).to eq("Gainesville Wrecking")
      expect(result.first[:edit_path]).to eq(
        helper.edit_activities_flow_income_employment_path(id: activity.id)
      )
      expect(result.first[:months]).to contain_exactly(
        { month: first_month, gross_earnings: 50000, hours: 40 },
        { month: second_month, gross_earnings: 30000, hours: 20 }
      )
    end

    it "returns empty months when no monthly entries exist" do
      activity.employment_activity_months.destroy_all

      result = helper.employment_activity_cards([ activity ])
      expect(result.first[:months]).to eq([])
    end
  end

  describe "#combined_employment_card_data" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }
    let(:reporting_range) { flow.reporting_window_range }
    let(:account_id) { "test-account-123" }
    let(:payroll_account) { build(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: account_id) }
    let(:employment_activity) { create(:employment_activity, activity_flow: flow, employer_name: "Gainesville Wrecking") }
    let(:mock_report) do
      instance_double(Aggregators::AggregatorReports::AggregatorReport).tap do |report|
        account_report = double(employment: double(employer_name: "ACME Corp"))
        allow(report).to receive(:find_account_report).with(account_id).and_return(account_report)
        allow(report).to receive(:summarize_by_month).and_return({ account_id => {} })
      end
    end

    before do
      create(:employment_activity_month, employment_activity:, month: flow.reporting_months.first.beginning_of_month, gross_income: 500, hours: 40)
    end

    it "combines payroll and self-attested employment cards" do
      result = helper.combined_employment_card_data(
        reporting_range: reporting_range,
        payroll_accounts: [ payroll_account ],
        persisted_report: mock_report,
        employment_activities: [ employment_activity ]
      )

      expect(result.map { |card| card[:name] }).to contain_exactly("ACME Corp", "Gainesville Wrecking")
    end
  end
end

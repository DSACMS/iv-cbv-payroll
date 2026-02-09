require "rails_helper"

RSpec.describe ActivitiesHelper do
  describe "#self_attestation_cards" do
    let(:flow) { create(:activity_flow, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }
    let(:first_month) { flow.reporting_window_range.begin }

    context "with community service activities" do
      it "returns one card per activity" do
        create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 5, date: first_month)
        create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 10, date: first_month + 5.days)

        result = helper.self_attestation_cards(flow.volunteering_activities, name_field: :organization_name)

        expect(result.length).to eq(2)
        expect(result.map { |c| c[:name] }).to all(eq("Food Pantry"))
      end

      it "includes the activity's name and hours" do
        create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 5, date: first_month)

        result = helper.self_attestation_cards(flow.volunteering_activities, name_field: :organization_name)

        expect(result.first[:name]).to eq("Food Pantry")
        expect(result.first[:months].first[:hours]).to eq(5)
        expect(result.first[:months].first[:month]).to eq(first_month.beginning_of_month)
      end

      it "returns the activity object for edit/delete links" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 5, date: first_month)

        result = helper.self_attestation_cards(flow.volunteering_activities, name_field: :organization_name)

        expect(result.first[:activity]).to eq(activity)
      end

      it "returns empty array for empty input" do
        result = helper.self_attestation_cards([], name_field: :organization_name)

        expect(result).to eq([])
      end

      it "returns empty months for activities with nil dates" do
        activity = build(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 5)
        activity.date = nil
        activity.save(validate: false)

        result = helper.self_attestation_cards(flow.volunteering_activities.reload, name_field: :organization_name)

        expect(result.first[:months]).to be_empty
      end
    end

    context "with work programs activities" do
      it "uses program_name as card name" do
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main", hours: 5, date: first_month)

        result = helper.self_attestation_cards(flow.job_training_activities, name_field: :program_name)

        expect(result.first[:name]).to eq("Career Prep")
      end

      it "returns one card per activity even with same program name" do
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main", hours: 5, date: first_month + 1.day)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main", hours: 8, date: first_month + 3.days)

        result = helper.self_attestation_cards(flow.job_training_activities, name_field: :program_name)

        expect(result.length).to eq(2)
      end
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

    it "falls back to Education title when no enrollment terms" do
      activity = create(:education_activity, activity_flow: flow, credit_hours: 12)

      result = helper.education_cards([ activity ], reporting_months)

      expect(result.first[:name]).to eq("Education")
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

      result = helper.education_cards([ activity ], reporting_months)

      months = result.first[:months].map { |m| m[:month] }
      expect(months).to eq(months.sort.reverse)
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
            month_key => { accrued_gross_earnings: 250_000, total_w2_hours: 80.0, total_gig_hours: 5.0 }
          }
        })
      end
    end

    let(:payroll_account) { build(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: account_id) }

    it "returns employer name from aggregator report" do
      result = helper.employment_cards([ payroll_account ], mock_report, reporting_range)

      expect(result.first[:name]).to eq("ACME Corp")
    end

    it "returns monthly gross earnings in cents and combined hours" do
      result = helper.employment_cards([ payroll_account ], mock_report, reporting_range)

      month_data = result.first[:months].first
      expect(month_data[:gross_earnings]).to eq(250_000)
      expect(month_data[:hours]).to eq(85)
    end

    it "returns empty array when aggregator report is nil" do
      result = helper.employment_cards([ payroll_account ], nil, reporting_range)

      expect(result).to eq([])
    end

    it "falls back to N/A when employer name is unavailable" do
      allow(mock_report).to receive(:find_account_report).with(account_id).and_return(nil)

      result = helper.employment_cards([ payroll_account ], mock_report, reporting_range)

      expect(result.first[:name]).to eq(I18n.t("shared.not_applicable"))
    end

    it "handles accounts with no monthly data" do
      allow(mock_report).to receive(:summarize_by_month).and_return({})

      result = helper.employment_cards([ payroll_account ], mock_report, reporting_range)

      expect(result.first[:months]).to be_empty
    end
  end

  describe "#enrollment_status_display" do
    it "maps full_time to Full-time" do
      expect(helper.enrollment_status_display("full_time")).to eq("Full-time")
    end

    it "maps three_quarter_time to Three-quarter Time" do
      expect(helper.enrollment_status_display("three_quarter_time")).to eq("Three-quarter Time")
    end

    it "maps half_time to Half-time" do
      expect(helper.enrollment_status_display("half_time")).to eq("Half-time")
    end

    it "maps less_than_half_time to Less than half-time" do
      expect(helper.enrollment_status_display("less_than_half_time")).to eq("Less than half-time")
    end

    it "maps enrolled to Enrolled" do
      expect(helper.enrollment_status_display("enrolled")).to eq("Enrolled")
    end

    it "maps unknown to N/A" do
      expect(helper.enrollment_status_display("unknown")).to eq(I18n.t("shared.not_applicable"))
    end
  end
end

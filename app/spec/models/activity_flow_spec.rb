require 'rails_helper'

RSpec.describe ActivityFlow, type: :model do
  it "cleans up related volunteering activities when destroyed" do
    flow = create(:activity_flow)

    expect { flow.destroy }
      .to change(VolunteeringActivity, :count).by(-flow.volunteering_activities.count)
      .and change(JobTrainingActivity, :count).by(-flow.job_training_activities.count)
      .and change(EducationActivity, :count).by(-EducationActivity.where(activity_flow_id: flow.id).count)
  end

  it "belongs to a CBV applicant" do
    cbv_applicant = create(:cbv_applicant)
    activity_flow = create(:activity_flow, cbv_applicant: cbv_applicant)

    expect(activity_flow.cbv_applicant).to eq(cbv_applicant)
  end

  describe ".create_from_invitation" do
    let(:device_id) { "device123" }

    it "creates a flow from an invitation" do
      invitation = create(:activity_flow_invitation)

      flow = described_class.create_from_invitation(invitation, device_id)

      expect(flow).to be_persisted
      expect(flow.activity_flow_invitation).to eq(invitation)
      expect(flow.device_id).to eq(device_id)
      expect(flow.cbv_applicant).to be_present
    end

    it "uses invitation's cbv_applicant if present" do
      cbv_applicant = create(:cbv_applicant)
      invitation = create(:activity_flow_invitation, cbv_applicant: cbv_applicant)

      flow = described_class.create_from_invitation(invitation, device_id)

      expect(flow.cbv_applicant).to eq(cbv_applicant)
    end
  end

  describe "reporting_window" do
    let(:flow) { create(:activity_flow, reporting_window_months: 2) }

    around do |example|
      Timecop.freeze(Time.zone.local(2025, 3, 15, 12, 0, 0)) { example.run }
    end

    it "ends on the last day of the last completed month" do
      expect(flow.reporting_window_range.end).to eq(Date.new(2025, 2, 28))
    end

    it "returns a range spanning the configured months" do
      expect(flow.reporting_window_range).to eq(Date.new(2025, 1, 1)..Date.new(2025, 2, 28))
    end

    it "returns a formatted display string" do
      expect(flow.reporting_window_display).to eq("January 2025 - February 2025")
    end

    describe "#within_reporting_window?" do
      it "returns true when date range overlaps with reporting window" do
        expect(flow.within_reporting_window?(Date.new(2024, 12, 1), Date.new(2025, 1, 15))).to be true
        expect(flow.within_reporting_window?(Date.new(2025, 2, 15), Date.new(2025, 4, 1))).to be true
        expect(flow.within_reporting_window?(Date.new(2024, 12, 1), Date.new(2025, 4, 1))).to be true
      end

      it "returns false when date range does not overlap with reporting window" do
        expect(flow.within_reporting_window?(Date.new(2024, 10, 1), Date.new(2024, 12, 31))).to be false
        expect(flow.within_reporting_window?(Date.new(2025, 3, 1), Date.new(2025, 5, 1))).to be false
      end
    end
  end

  it 'marked as complete when completed_at timestamp is set' do
    flow = create(:activity_flow, completed_at: nil)
    expect(flow).not_to be_complete

    flow.update(completed_at: Time.current)
    expect(flow).to be_complete
  end

  describe "#aggregator_lookback_days" do
    it "returns the number of days in the reporting window" do
      flow = create(:activity_flow, reporting_window_months: 2)
      expected_days = flow.reporting_window_range.to_a.size
      expect(flow.aggregator_lookback_days).to eq({ w2: expected_days, gig: expected_days })
    end
  end

  describe "#after_payroll_sync_succeeded" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1) }
    let(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: "acct-1") }
    let(:report) { instance_double(Aggregators::AggregatorReports::AggregatorReport) }

    before do
      allow(report).to receive_messages(
        has_fetched?: true,
        summarize_by_month: { "acct-1" => {} }
      )
      allow(report).to receive(:find_account_report).with("acct-1").and_return(
        double(employment: double(employer_name: "Test Employer", employment_type: :w2))
      )
    end

    it "persists monthly summaries from the report" do
      expect {
        flow.after_payroll_sync_succeeded(payroll_account, report)
      }.to change { flow.activity_flow_monthly_summaries.count }.by(flow.reporting_months.size)
    end
  end

  describe "#any_activities_added?" do
    let(:flow) do
      create(
        :activity_flow,
        volunteering_activities_count: 0,
        job_training_activities_count: 0,
        education_activities_count: 0
      )
    end

    it "returns false when flow has no activities" do
      expect(flow.any_activities_added?).to be false
    end

    it "returns false when flow has an education activity without enrollment data" do
      create(:education_activity, activity_flow: flow)

      expect(flow.any_activities_added?).to be false
    end

    it "returns true when flow has an education activity with enrollment data" do
      education_activity = create(:education_activity, activity_flow: flow)
      create(:nsc_enrollment_term, education_activity:)

      expect(flow.any_activities_added?).to be true
    end

    [
      [ :volunteering_activity, :activity_flow ],
      [ :job_training_activity, :activity_flow ],
      [ :payroll_account, :flow ]
    ].each do |factory_name, flow_attribute|
      activity_name = factory_name.to_s.humanize.downcase

      it "returns true when flow includes #{activity_name}" do
        create(factory_name, flow_attribute => flow)
        expect(flow.any_activities_added?).to be true
      end
    end
  end
end

require "rails_helper"

RSpec.describe ActivityFlowEmploymentSummary, type: :model do
  describe "validations" do
    it "allows one employment summary per activity flow and payroll account" do
      summary = create(:activity_flow_employment_summary)
      duplicate_summary = build(
        :activity_flow_employment_summary,
        activity_flow: summary.activity_flow,
        payroll_account: summary.payroll_account
      )

      expect(duplicate_summary).not_to be_valid
    end
  end

  describe "#redact!" do
    it "redacts persisted employer fields" do
      summary = create(
        :activity_flow_employment_summary,
        employer_name: "Acme Employer",
        employment_type: "w2",
        employer_phone_number: "6045551234",
        employer_address: "123 Main St",
        employment_status: "employed",
        employment_start_date: Date.new(2024, 1, 15),
        employment_termination_date: Date.new(2024, 3, 15)
      )

      summary.redact!

      expect(summary.reload).to have_attributes(
        employer_name: "REDACTED",
        employment_type: "REDACTED",
        employer_phone_number: "REDACTED",
        employer_address: "REDACTED",
        employment_status: "REDACTED",
        employment_start_date: Date.new(1990, 1, 1),
        employment_termination_date: Date.new(1990, 1, 1),
        redacted_at: be_present
      )
    end
  end

  describe ".persist_from_report" do
    let(:flow) { create(:activity_flow, reporting_window_months: 2) }
    let(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: "acct-1") }
    let(:report) { instance_double(Aggregators::AggregatorReports::AggregatorReport) }

    before do
      allow(report).to receive(:has_fetched?).and_return(true)
      allow(report).to receive(:find_account_report).with("acct-1").and_return(
        double(employment: instance_double(Aggregators::ResponseObjects::Employment,
          employer_name: "Acme Employer",
          employment_type: :w2,
          employer_phone_number: "6045551234",
          employer_address: "123 Main St",
          status: "employed",
          start_date: Date.new(2024, 1, 15),
          termination_date: nil
        ))
      )
    end

    it "persists one employer summary per payroll account" do
      described_class.persist_from_report(activity_flow: flow, payroll_account: payroll_account, report: report)

      expect(described_class.where(activity_flow: flow, payroll_account: payroll_account).count).to eq(1)
      expect(described_class.find_by(activity_flow: flow, payroll_account: payroll_account)).to have_attributes(
        employer_name: "Acme Employer",
        employment_type: "w2",
        employer_phone_number: "6045551234",
        employer_address: "123 Main St",
        employment_status: "employed",
        employment_start_date: Date.new(2024, 1, 15),
        employment_termination_date: nil
      )
    end

    it "refreshes an existing redacted employer summary" do
      create(
        :activity_flow_employment_summary,
        activity_flow: flow,
        payroll_account: payroll_account,
        employer_name: "REDACTED",
        redacted_at: 1.day.ago
      )

      described_class.persist_from_report(activity_flow: flow, payroll_account: payroll_account, report: report)

      expect(described_class.find_by(activity_flow: flow, payroll_account: payroll_account)).to have_attributes(
        employer_name: "Acme Employer",
        redacted_at: nil
      )
    end
  end

  describe ".by_account_with_fallback" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1) }
    let!(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: "acct-1") }

    context "when complete persisted data exists" do
      let!(:draft_account) do
        create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: "draft-acct", draft: true)
      end

      before do
        create(
          :activity_flow_employment_summary,
          activity_flow: flow,
          payroll_account: payroll_account,
          employer_name: "Persisted Employer",
          employment_type: "w2",
          employer_phone_number: "6045551234"
        )
        create(
          :activity_flow_employment_summary,
          activity_flow: flow,
          payroll_account: draft_account,
          employer_name: "Draft Employer",
          employment_type: "w2"
        )
      end

      it "returns persisted published account data without fetching from the aggregator" do
        allow(AggregatorReportFetcher).to receive(:new).and_raise("should not fetch")

        result = described_class.by_account_with_fallback(activity_flow: flow)

        expect(result.keys).to eq([ "acct-1" ])
        expect(result["acct-1"]).to include(
          employer_name: "Persisted Employer",
          employment_type: "w2",
          employer_phone_number: "6045551234"
        )
      end
    end

    context "when persisted data is incomplete" do
      let(:month_key) { flow.reporting_months.first.strftime("%Y-%m") }
      let(:mock_report) { instance_double(Aggregators::AggregatorReports::AggregatorReport) }

      before do
        allow(mock_report).to receive_messages(
          has_fetched?: true,
          summarize_by_month: {
            "acct-1" => {
              month_key => {
                total_w2_hours: 10.0,
                accrued_gross_earnings: 50_00
              }
            }
          }
        )
        allow(mock_report).to receive(:find_account_report).with("acct-1").and_return(
          double(employment: instance_double(Aggregators::ResponseObjects::Employment,
            employer_name: "Fetched Employer",
            employment_type: :w2,
            employer_phone_number: "6045551234",
            employer_address: "123 Main St",
            status: "employed",
            start_date: Date.new(2024, 1, 15),
            termination_date: nil
          ))
        )
        allow(AggregatorReportFetcher).to receive(:new).with(flow).and_return(double(report: mock_report))
      end

      it "falls back to fetching and persists employment data" do
        result = described_class.by_account_with_fallback(activity_flow: flow)

        expect(result["acct-1"]).to include(
          employer_name: "Fetched Employer",
          employer_phone_number: "6045551234",
          employment_start_date: Date.new(2024, 1, 15)
        )
        expect(flow.activity_flow_employment_summaries.where(payroll_account: payroll_account).count).to eq(1)
      end
    end
  end
end

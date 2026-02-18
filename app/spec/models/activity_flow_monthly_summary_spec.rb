require "rails_helper"

RSpec.describe ActivityFlowMonthlySummary, type: :model do
  describe "#redact!" do
    it "redacts employer and clears persisted income fields" do
      summary = create(
        :activity_flow_monthly_summary,
        employer_name: "Acme Employer",
        total_w2_hours: 12.5,
        total_gig_hours: 8.0,
        accrued_gross_earnings_cents: 123_45,
        total_mileage: 15.2
      )

      summary.redact!

      expect(summary.reload).to have_attributes(
        employer_name: "REDACTED",
        total_w2_hours: 0.0,
        total_gig_hours: 0.0,
        accrued_gross_earnings_cents: 0,
        total_mileage: 0.0,
        redacted_at: be_present
      )
    end
  end

  describe ".upsert_from_report" do
    let(:flow) { create(:activity_flow, reporting_window_months: 2) }
    let(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: "acct-1") }
    let(:report) { instance_double(Aggregators::AggregatorReports::AggregatorReport) }
    let(:range) { flow.reporting_window_range }
    let(:month_1_key) { range.begin.strftime("%Y-%m") }
    let(:month_2_key) { (range.begin + 1.month).strftime("%Y-%m") }

    before do
      allow(report).to receive(:has_fetched?).and_return(true)
      allow(report).to receive(:find_account_report).with("acct-1").and_return(
        double(employment: double(employer_name: "Acme Employer", employment_type: :w2))
      )
    end

    it "persists one row per reporting month and fills missing months with zeros" do
      allow(report).to receive(:summarize_by_month).and_return(
        "acct-1" => {
          month_1_key => {
            total_w2_hours: 40.0,
            total_gig_hours: 10.0,
            accrued_gross_earnings: 250_00,
            total_mileage: 12.5
          }
        }
      )

      described_class.upsert_from_report(activity_flow: flow, payroll_account: payroll_account, report: report)

      summaries = described_class.where(activity_flow: flow, payroll_account: payroll_account).order(:month)
      expect(summaries.length).to eq(2)

      expect(summaries.first).to have_attributes(
        month: range.begin.beginning_of_month,
        total_w2_hours: 40.0,
        total_gig_hours: 10.0,
        accrued_gross_earnings_cents: 250_00,
        total_mileage: 12.5,
        employer_name: "Acme Employer"
      )

      expect(summaries.second).to have_attributes(
        month: (range.begin + 1.month).beginning_of_month,
        total_w2_hours: 0.0,
        total_gig_hours: 0.0,
        accrued_gross_earnings_cents: 0,
        total_mileage: 0.0,
        employer_name: "Acme Employer"
      )
    end
  end

  describe ".by_account_with_fallback" do
    let(:flow) { create(:activity_flow, reporting_window_months: 1) }
    let!(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: "acct-1") }

    context "when complete persisted data exists" do
      before do
        flow.reporting_months.each do |month|
          create(:activity_flow_monthly_summary,
            activity_flow: flow,
            payroll_account: payroll_account,
            month: month.beginning_of_month,
            employer_name: "Persisted Employer",
            total_w2_hours: 40.0,
            accrued_gross_earnings_cents: 100_00)
        end
      end

      it "returns persisted data without fetching from the aggregator" do
        allow(AggregatorReportFetcher).to receive(:new).and_raise("should not fetch")

        result = described_class.by_account_with_fallback(activity_flow: flow)

        expect(result.keys).to eq([ "acct-1" ])
        month_key = flow.reporting_months.first.strftime("%Y-%m")
        expect(result["acct-1"][month_key]).to include(
          employer_name: "Persisted Employer",
          total_w2_hours: 40.0,
          accrued_gross_earnings: 100_00
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
                total_gig_hours: 0.0,
                accrued_gross_earnings: 50_00,
                total_mileage: 0.0
              }
            }
          }
        )
        allow(mock_report).to receive(:find_account_report).with("acct-1").and_return(
          double(employment: double(employer_name: "Fetched Employer", employment_type: :w2))
        )
        allow(AggregatorReportFetcher).to receive(:new).with(flow).and_return(double(report: mock_report))
      end

      it "falls back to fetching and returns the fetched data" do
        result = described_class.by_account_with_fallback(activity_flow: flow)

        expect(result["acct-1"][month_key]).to include(
          employer_name: "Fetched Employer",
          accrued_gross_earnings: 50_00
        )
      end

      it "persists summary rows for each reporting month" do
        described_class.by_account_with_fallback(activity_flow: flow)

        expect(flow.activity_flow_monthly_summaries.where(payroll_account: payroll_account).count)
          .to eq(flow.reporting_months.size)
      end
    end

    context "when there is no report available" do
      before do
        allow(AggregatorReportFetcher).to receive(:new).with(flow).and_return(double(report: nil))
      end

      it "returns an empty hash" do
        expect(described_class.by_account_with_fallback(activity_flow: flow)).to eq({})
      end
    end
  end
end

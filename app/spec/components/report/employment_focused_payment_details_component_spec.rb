require "rails_helper"

RSpec.describe Report::EmploymentFocusedPaymentDetailsComponent, type: :component do
  let(:flow) { instance_double(ActivityFlow, reporting_months: [ Date.new(2026, 1, 1), Date.new(2026, 2, 1) ]) }
  let(:payroll_account) { instance_double(PayrollAccount, aggregator_account_id: "synthetic-account", job_succeeded?: true) }
  let(:employment) { Struct.new(:start_date, :termination_date, :status).new("2025-01-01", nil, "active") }
  let(:income) { Struct.new(:pay_frequency, :compensation_amount, :compensation_unit).new("biweekly", 2500, "hourly") }
  let(:account_report) { Struct.new(:employment, :income).new(employment, income) }
  let(:summary) do
    {
      "2026-01" => { paystubs: [ Object.new, Object.new ], accrued_gross_earnings: 150000, total_w2_hours: 80, gigs: [ Object.new ], total_gig_hours: 12.5 }
    }
  end
  let(:report) do
    instance_double(Aggregators::AggregatorReports::AggregatorReport,
      flow: flow, find_account_report: account_report,
      summarize_by_month: { "synthetic-account" => summary })
  end

  it "renders the requested employment fields and one table per reporting month" do
    rendered = render_inline(described_class.new(report, payroll_account, is_w2_worker: true))

    expect(rendered).to have_selector("h2", text: "Employment information")
    expect(rendered).to have_selector("h2", text: "Monthly details")
    expect(rendered).to have_selector("table", count: 3)
    expect(rendered).to have_selector("table.maxw-none[aria-label]", count: 2)
    employment_table = rendered.css("table").first
    expect(employment_table.css("tbody th").map { |cell| cell.text.strip }).to eq([
      "Employment start date", "Employment end date", "Employment status", "Pay frequency", "Compensation amount"
    ])
    expect(employment_table).to have_text("January 1, 2025")
    expect(employment_table).to have_text("$25.00")
    expect(rendered).to have_no_text("Employer address")

    january = rendered.at_css('table[aria-label="January 2026"]')
    expect(january.css("th").map { |cell| cell.text.strip }).to eq([ "Month", "Gross income", "Number of paychecks", "Hours worked" ])
    expect(january.css("td").map { |cell| cell.text.strip }).to eq([ "January 2026", "$1,500.00", "2", "80.0" ])
    february = rendered.at_css('table[aria-label="February 2026"]')
    expect(february.css("td").map { |cell| cell.text.strip }).to eq([ "February 2026", "N/A", "0", "N/A" ])
  end

  it "uses gig hours for gig workers" do
    rendered = render_inline(described_class.new(report, payroll_account, is_w2_worker: false))

    expect(rendered.at_css('table[aria-label="January 2026"]').css("td").last.text).to eq("12.5")
  end

  it "does not format missing compensation as zero" do
    income.compensation_amount = nil
    rendered = render_inline(described_class.new(report, payroll_account, is_w2_worker: true))

    expect(rendered.css("table").first.css("tbody tr").last).to have_text("N/A")
    expect(rendered).to have_no_text("$0.00")
  end
end

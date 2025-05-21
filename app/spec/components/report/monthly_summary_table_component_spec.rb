require "rails_helper"

RSpec.describe Report::MonthlySummaryTableComponent, type: :component do
  include ArgyleApiHelper
  let(:current_time) { Date.parse('2024-06-18') }
  let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
  let(:account_id) { "019571bc-2f60-3955-d972-dbadfe0913a8" }
  let(:cbv_flow) do
    create(:cbv_flow,
           :invited,
           created_at: current_time,
           cbv_applicant: cbv_applicant
    )
  end
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new("sandbox") }
  let!(:payroll_account) do
    create(
      :payroll_account,
      :argyle_fully_synced,
      cbv_flow: cbv_flow,
      pinwheel_account_id: account_id
      )
  end

  context "with argyle stubs" do
    context "with bob, a gig-worker" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service) }# , from_date: current_time, to_date: current_time) }
      before do
        # session[:cbv_flow_id] = cbv_flow.id
        argyle_stub_request_identities_response("bob")
        argyle_stub_request_paystubs_response("bob")
        argyle_stub_request_gigs_response("bob")
        argyle_stub_request_account_response("bob")
        Timecop.freeze(Time.local(2025, 04, 1, 0, 0))
        # allow(argyle_service).to receive(:fetch_account_api).and_return(argyle_load_relative_json_file("bob", "request_account.json"))
        # allow(argyle_service).to receive(:fetch_identities_api).and_return(argyle_load_relative_json_file("bob", "request_identity.json"))
        # allow(argyle_service).to receive(:fetch_paystubs_api).and_return(argyle_load_relative_json_file("bob", "request_paystubs.json"))
        argyle_report.fetch
      end

      it "argyle_report is properly fetched" do
        expect(argyle_report.gigs.length).to be(100)
      end

      it "renders helllllo" do
        rendered_page = render_inline(described_class.new(argyle_report, payroll_account))
        puts(rendered_page)
        expect(rendered_page
        ).to have_text(
               "Helllllllo"
             )
      end

      describe "#summarize_by_month" do
        xit "returns a hash of monthly totals" do
          summary_component = described_class.new(argyle_report, payroll_account)
          expect(summary_component.summarize_by_month(from_date: Date.parse("2025-01-08"))).to eq({
            "2025-04" => {
              "gigs" => 100,
              "paystubs" => 100,
              "payroll_accounts" => 1,
              "total_payroll_accounts" => 1,
              "total_gigs" => 100,
              "total_paystubs" => 100
            }
          })
        end
      end
    end
  end

  describe ".partial_month_details" do
    it "detects complete month when there are no activities" do
      current_month_string = "2025-01"
      activity_dates = []
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = described_class.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: false,
                                                         included_range_start: "2025-01-01",
                                                         included_range_end: "2025-01-31"
                                                       })
    end

    it "detects complete first month when there is an activity on the first day" do
      current_month_string = "2025-01"
      activity_dates = [ Date.parse("2025-01-01") ]
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = described_class.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: false,
                                                         included_range_start: "2025-01-01",
                                                         included_range_end: "2025-01-31"
                                                       })
    end

    it "detects complete last month when there is an activity on the last day" do
      current_month_string = "2025-03"
      activity_dates = [ Date.parse("2025-03-31") ]
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = described_class.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: false,
                                                         included_range_start: "2025-03-01",
                                                         included_range_end: "2025-03-31"
                                                       })
    end

    it "detects partial first month" do
      current_month_string = "2025-01"
      activity_dates = [ Date.parse("2025-01-04"), Date.parse("2025-01-06") ]
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = described_class.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: true,
                                                         included_range_start: "2025-01-04",
                                                         included_range_end: "2025-01-31"
                                                       })
    end

    it "detects partial last month" do
      current_month_string = "2025-03"
      activity_dates = [ Date.parse("2025-03-04"), Date.parse("2025-03-06") ]
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = described_class.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: true,
                                                         included_range_start: "2025-03-01",
                                                         included_range_end: "2025-03-06"
                                                       })
    end
  end

  describe ".parse_date_safely" do
    it "parses a valid date string" do
      valid_date = "2024-12-25"
      parsed_date = described_class.parse_date_safely(valid_date)
      expect(parsed_date).to eq(Date.parse(valid_date))
    end

    it "returns nil for an invalid date string" do
      invalid_date = "invalid-date-string"
      parsed_date = described_class.parse_date_safely(invalid_date)
      expect(parsed_date).to be_nil
    end

    it "returns nil for nil input" do
      parsed_date = described_class.parse_date_safely(nil)
      expect(parsed_date).to be_nil
    end

    it "returns nil for empty string input" do
      parsed_date = described_class.parse_date_safely("")
      expect(parsed_date).to be_nil
    end
  end

  describe ".parse_month_safely" do
    it "parses a valid month string" do
      valid_month = "2024-12"
      parsed_date = described_class.parse_month_safely(valid_month)
      expect(parsed_date).to eq(Date.new(2024, 12, 01))
    end

    it "returns nil for an invalid month string" do
      invalid_month = "invalid-month-string"
      parsed_date = described_class.parse_month_safely(invalid_month)
      expect(parsed_date).to be_nil
    end

    it "returns nil for nil input" do
      parsed_date = described_class.parse_month_safely(nil)
      expect(parsed_date).to be_nil
    end

    it "returns nil for empty string input" do
      parsed_date = described_class.parse_month_safely("")
      expect(parsed_date).to be_nil
    end
  end

  describe ".format_date" do
    it "formats a valid date correctly" do
      date = Date.new(2024, 12, 25)
      formatted_date = described_class.format_date(date)
      expect(formatted_date).to eq("2024-12-25")
    end

    it "returns nil for nil input" do
      formatted_date = described_class.format_date(nil)
      expect(formatted_date).to be_nil
    end
  end

  describe ".format_month" do
    it "formats a valid month correctly" do
      month = Date.new(2024, 12, 13)
      formatted_month = described_class.format_month(month)
      expect(formatted_month).to eq("2024-12")
    end

    it "returns nil for nil input" do
      formatted_month = described_class.format_month(nil)
      expect(formatted_month).to be_nil
    end
  end

  describe ".unique_months" do
    it "returns a unique list of months in reverse chronological order" do
      dates = [
        Date.new(2025, 3, 15),
        Date.new(2025, 2, 25),
        Date.new(2025, 3, 5),
        Date.new(2025, 1, 1)
      ]

      unique_months = described_class.unique_months(dates)

      expect(unique_months).to eq([ "2025-03", "2025-02", "2025-01" ])
    end

    it "returns an empty array when given an empty list" do
      dates = []

      unique_months = described_class.unique_months(dates)

      expect(unique_months).to eq([])
    end

    it "handles a list with dates all in the same month" do
      dates = [
        Date.new(2025, 3, 15),
        Date.new(2025, 3, 5),
        Date.new(2025, 3, 10)
      ]

      unique_months = described_class.unique_months(dates)

      expect(unique_months).to eq([ "2025-03" ])
    end

    it "handles nil values gracefully" do
      dates = [
        Date.new(2025, 3, 15),
        nil,
        Date.new(2025, 3, 5)
      ]

      unique_months = described_class.unique_months(dates)

      expect(unique_months).to eq([ "2025-03" ])
    end

    it "handles a list with only nil values" do
      dates = [ nil, nil, nil ]

      unique_months = described_class.unique_months(dates)

      expect(unique_months).to eq([])
    end
  end
end

require "rails_helper"

RSpec.describe Report::MonthlySummaryTableHelper, type: :helper do
  subject {  helper }
  describe ".partial_month_details" do
    it "detects complete month when there are no activities" do
      current_month_string = "2025-01"
      activity_dates = []
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = subject.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: false,
                                                         description: nil,
                                                         included_range_start: Date.parse("2025-01-01"),
                                                         included_range_end: Date.parse("2025-01-31")
                                                       })
    end

    it "detects complete first month when there is an activity on the first day" do
      current_month_string = "2025-01"
      activity_dates = [ Date.parse("2025-01-01") ]
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = subject.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: false,
                                                         description: nil,
                                                         included_range_start: Date.parse("2025-01-01"),
                                                         included_range_end: Date.parse("2025-01-31")
                                                       })
    end

    it "detects complete last month when there is an activity on the last day" do
      current_month_string = "2025-03"
      activity_dates = [ Date.parse("2025-03-31") ]
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = subject.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: false,
                                                         description: nil,
                                                         included_range_start: Date.parse("2025-03-01"),
                                                         included_range_end: Date.parse("2025-03-31")
                                                       })
    end

    it "detects partial first month" do
      current_month_string = "2025-01"
      activity_dates = [ Date.parse("2025-01-04"), Date.parse("2025-01-06") ]
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = subject.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: true,
                                                         description: "(Partial month: from 1/4-1/31)",
                                                         included_range_start: Date.parse("2025-01-04"),
                                                         included_range_end: Date.parse("2025-01-31")
                                                       })
    end

    it "detects partial last month" do
      current_month_string = "2025-03"
      activity_dates = [ Date.parse("2025-03-04"), Date.parse("2025-03-06") ]
      from_date = Date.parse("2025-01-01")
      to_date = Date.parse("2025-03-31")

      partial_month_details = subject.partial_month_details(current_month_string, activity_dates, from_date, to_date)
      expect(partial_month_details).to an_object_eq_to({
                                                         is_partial_month: true,
                                                         description: "(Partial month: from 3/1-3/6)",
                                                         included_range_start: Date.parse("2025-03-01"),
                                                         included_range_end: Date.parse("2025-03-06")
                                                       })
    end
  end

  describe ".parse_date_safely" do
    it "parses a valid date string" do
      valid_date = "2024-12-25"
      parsed_date = subject.parse_date_safely(valid_date)
      expect(parsed_date).to eq(Date.parse(valid_date))
    end

    it "returns nil for an invalid date string" do
      invalid_date = "invalid-date-string"
      parsed_date = subject.parse_date_safely(invalid_date)
      expect(parsed_date).to be_nil
    end

    it "returns nil for nil input" do
      parsed_date = subject.parse_date_safely(nil)
      expect(parsed_date).to be_nil
    end

    it "returns nil for empty string input" do
      parsed_date = subject.parse_date_safely("")
      expect(parsed_date).to be_nil
    end
  end

  describe ".parse_month_safely" do
    it "parses a valid month string" do
      valid_month = "2024-12"
      parsed_date = subject.parse_month_safely(valid_month)
      expect(parsed_date).to eq(Date.new(2024, 12, 01))
    end

    it "returns nil for an invalid month string" do
      invalid_month = "invalid-month-string"
      parsed_date = subject.parse_month_safely(invalid_month)
      expect(parsed_date).to be_nil
    end

    it "returns nil for nil input" do
      parsed_date = subject.parse_month_safely(nil)
      expect(parsed_date).to be_nil
    end

    it "returns nil for empty string input" do
      parsed_date = subject.parse_month_safely("")
      expect(parsed_date).to be_nil
    end
  end

  describe ".format_month" do
    it "formats a valid month correctly" do
      month = Date.new(2024, 12, 13)
      formatted_month = subject.format_month(month)
      expect(formatted_month).to eq("2024-12")
    end

    it "returns nil for nil input" do
      formatted_month = subject.format_month(nil)
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

      unique_months = subject.unique_months(dates)

      expect(unique_months).to eq([ "2025-03", "2025-02", "2025-01" ])
    end

    it "returns an empty array when given an empty list" do
      dates = []

      unique_months = subject.unique_months(dates)

      expect(unique_months).to eq([])
    end

    it "handles a list with dates all in the same month" do
      dates = [
        Date.new(2025, 3, 15),
        Date.new(2025, 3, 5),
        Date.new(2025, 3, 10)
      ]

      unique_months = subject.unique_months(dates)

      expect(unique_months).to eq([ "2025-03" ])
    end

    it "handles nil values gracefully" do
      dates = [
        Date.new(2025, 3, 15),
        nil,
        Date.new(2025, 3, 5)
      ]

      unique_months = subject.unique_months(dates)

      expect(unique_months).to eq([ "2025-03" ])
    end

    it "handles a list with only nil values" do
      dates = [ nil, nil, nil ]

      unique_months = subject.unique_months(dates)

      expect(unique_months).to eq([])
    end
  end
end

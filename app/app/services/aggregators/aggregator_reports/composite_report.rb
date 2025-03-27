module Aggregators::AggregatorReports
  class CompositeReport < AggregatorReport
    def initialize(aggregator_reports, **params)
      super(**params)
      combine_reports(aggregator_reports)
    end

    def fetch
      raise "Cannot fetch a composite report"
    end

    private
    def combine_reports(aggregator_reports)
      aggregator_reports.each do |aggregator_report|
        @payroll_accounts += aggregator_report.payroll_accounts
        @identities += aggregator_report.identities
        @employments += aggregator_report.employments
        @incomes += aggregator_report.incomes
        @paystubs += aggregator_report.paystubs

        @from_date = aggregator_report.from_date if is_earlier_date(aggregator_report.from_date, @from_date)
        @to_date = aggregator_report.to_date if is_earlier_date(@to_date, aggregator_report.to_date)
      end
      @has_fetched = true
    end

    def is_earlier_date(a, b)
      if a.present? and b.present?
        Date.parse(a) < Date.parse(b)
      elsif a.present?
        Date.parse(a)
      elsif b.present?
        Date.parse(b)
      else
        nil
      end
    end
  end
end

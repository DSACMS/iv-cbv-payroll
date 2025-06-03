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

        @fetched_days = [ @fetched_days, aggregator_report.fetched_days ].max
      end
      @has_fetched = true
    end
  end
end

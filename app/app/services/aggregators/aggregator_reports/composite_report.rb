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

        @from_date = earlier_date(aggregator_report.from_date, @from_date)
        @to_date = later_date(@to_date, aggregator_report.to_date)
      end
      @has_fetched = true
    end

    def earlier_date(a, b)
      a_date = a.to_date if a.present?
      b_date = b.to_date if b.present?

      if a_date.present? && b_date.present?
        [ a_date, b_date ].min
      elsif a_date.present?
        a_date
      elsif b_date.present?
        b_date
      end
    end

    def later_date(a, b)
      a_date = a.to_date if a.present?
      b_date = b.to_date if b.present?

      if a_date.present? && b_date.present?
        [ a_date, b_date ].max
      elsif a_date.present?
        a_date
      elsif b_date.present?
        b_date
      end
    end
  end
end

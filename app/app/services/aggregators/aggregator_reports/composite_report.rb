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
      if a.present? && b.present?
        if Date.parse(a) < Date.parse(b)
          a
        else
          b
        end
      elsif a.present?
        a
      elsif b.present?
        b
      else
        nil
      end
    end

    def later_date(a, b)
      if a.present? && b.present?
        if Date.parse(a) > Date.parse(b)
          a
        else
          b
        end
      elsif a.present?
        a
      elsif b.present?
        b
      else
        nil
      end
    end
  end
end

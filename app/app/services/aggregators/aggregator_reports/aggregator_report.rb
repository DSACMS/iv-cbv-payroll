# This is an abstract class that should be inherited by all aggregator report classes.
module Aggregators::AggregatorReports
  class AggregatorReport
    def initialize(payroll_accounts: [])
      @has_fetched = false
      @payroll_accounts = payroll_accounts
      @identities = []
      @incomes = []
      @employments = []
      @paystubs = []
    end

    # TODO: Make these params required. update tests.
    def fetch(from_date: nil, to_date: nil)
      return false unless is_ready_to_fetch?
      fetch_report_data(from_date, to_date)
    end

    def has_fetched?
      @has_fetched
    end

    def is_ready_to_fetch?
      @payroll_accounts.all? do |payroll_account|
        payroll_account.has_fully_synced?
      end
    end

    def identities
      @identities
    end

    def incomes
      @incomes
    end

    def employments
      @employments
    end

    def paystubs
      @paystubs
    end

    def summarize_by_employer
      @payroll_accounts
        .each_with_object({}) do |payroll_account, hash|
          account_id = payroll_account.pinwheel_account_id
          has_income_data = payroll_account.job_succeeded?("income")
          has_employment_data = payroll_account.job_succeeded?("employment")
          has_identity_data = payroll_account.job_succeeded?("identity")
          account_paystubs = @paystubs.filter { |paystub| paystub.account_id == account_id }

          hash[account_id] ||= {
            total: account_paystubs.sum { |paystub| paystub.gross_pay_amount },
            has_income_data: has_income_data,
            has_employment_data: has_employment_data,
            has_identity_data: has_identity_data,
            # TODO: what happens if more than one income/employment/identity on an account?
            income: has_income_data && @incomes.find { |income| income.account_id == account_id },
            employment: has_employment_data && @employments.find { |employment| employment.account_id == account_id },
            identity: has_identity_data && @identities.find { |identity| identity.account_id == account_id },
            paystubs: account_paystubs
          }
        end
    end

    def total_gross_income
      @paystubs.reduce(0) { |sum, paystub| sum + paystub.gross_pay_amount }
    end
  end

  private
  def fetch_report_data(from_date, to_date)
    raise "must implement in subclass"
  end
end

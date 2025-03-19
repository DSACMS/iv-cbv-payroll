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

    def fetch(from_date: nil, to_date: nil)
      return false unless is_ready_to_fetch?
      fetch_report_data(from_date: from_date, to_date: to_date)
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

    def summarize_by_employer(payments, employments, incomes, identities, pinwheel_accounts)
      pinwheel_accounts
        .each_with_object({}) do |pinwheel_account, hash|
          account_id = pinwheel_account.pinwheel_account_id
          has_income_data = pinwheel_account.job_succeeded?("income")
          has_employment_data = pinwheel_account.job_succeeded?("employment")
          has_identity_data = pinwheel_account.job_succeeded?("identity")
          account_payments = payments.filter { |payment| payment.account_id == account_id }
          hash[account_id] ||= {
            total: account_payments.sum { |payment| payment.gross_pay_amount },
            has_income_data: has_income_data,
            has_employment_data: has_employment_data,
            has_identity_data: has_identity_data,
            income: has_income_data && incomes.find { |income| income.account_id == account_id },
            employment: has_employment_data && employments.find { |employment| employment.account_id == account_id },
            identity: has_identity_data && identities.find { |identity| identity.account_id == account_id },
            payments: account_payments
          }
        end
    end

    def hours_by_earning_category(earnings)
    end

    def payments_grouped_by_employer
      summarize_by_employer(@payments, @employments, @incomes, @identities, @cbv_flow.payroll_accounts)
    end

    def total_gross_income
      @payments.reduce(0) { |sum, payment| sum + payment.gross_pay_amount }
    end
  end

  private
  def fetch_report_data
    raise "This method should be implemented in a subclass"
  end
end

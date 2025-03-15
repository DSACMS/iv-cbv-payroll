module Aggregators
  class AggregatorReport
    def initialize(payroll_accounts_ids: [])
      @has_fetched = false
      @payroll_account_ids = payroll_accounts_ids
      @identity = []
      @incomes = []
      @employments = []
      @paystubs = []
    end

    def fetch
      raise "This method should be implemented in a subclass"
    end

    def has_fetched?
      @has_fetched
    end

    def is_ready_to_fetch?
      # TODO: this should be based on whether the webhooks have synced
      true
    end

    def identity
      @identity
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
end

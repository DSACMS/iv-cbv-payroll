# This is an abstract class that should be inherited by all aggregator report classes.
module Aggregators::AggregatorReports
  class AggregatorReport
    attr_accessor :payroll_accounts, :identities, :incomes, :employments, :gigs, :paystubs, :from_date, :to_date, :has_fetched

    def initialize(payroll_accounts: [], from_date: nil, to_date: nil)
      @has_fetched = false
      @payroll_accounts = payroll_accounts
      @identities = []
      @incomes = []
      @employments = []
      @paystubs = []
      @gigs = []
      @from_date = from_date
      @to_date = to_date
    end

    # TODO: move from_date and to_date to fetch() method and make required.
    def fetch
      return false unless is_ready_to_fetch?
      fetch_report_data
    end

    def has_fetched?
      @has_fetched
    end

    def is_ready_to_fetch?
      @payroll_accounts.all? do |payroll_account|
        payroll_account.has_fully_synced?
      end
    end

    def fetch_report_data
      begin
        all_successful = true
        @payroll_accounts.each do |account|
            fetch_report_data_for_account(account)
          end
      rescue StandardError => e
        Rails.logger.error("Report Fetch Error: #{e.message}")
        all_successful = false
      end
      @has_fetched = all_successful
    end



    AccountReportStruct = Struct.new(:identity, :income, :employment, :paystubs)
    def find_account_report(account_id)
      AccountReportStruct.new(
      @identities.find { |identity| identity.account_id == account_id },
      @incomes.find { |income| income.account_id == account_id },
      @employments.find { |employment| employment.account_id == account_id },
      @paystubs.filter { |paystub| paystub.account_id == account_id },
      @gigs.filter { |gig| gig.account_id == account_id }
      )
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
            paystubs: account_paystubs,
            gigs: @gigs.filter { |gig| gig.account_id == account_id }
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

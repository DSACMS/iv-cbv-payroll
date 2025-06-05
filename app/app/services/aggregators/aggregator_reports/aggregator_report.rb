# This is an abstract class that should be inherited by all aggregator report classes.
module Aggregators::AggregatorReports
  class AggregatorReport
    include Cbv::MonthlySummaryHelper

    attr_accessor :payroll_accounts, :identities, :incomes, :employments, :gigs, :paystubs, :has_fetched, :fetched_days

    def initialize(payroll_accounts: [], days_to_fetch_for_w2: nil, days_to_fetch_for_gig: nil)
      @has_fetched = false
      @payroll_accounts = payroll_accounts
      @identities = []
      @incomes = []
      @employments = []
      @paystubs = []
      @gigs = []
      @days_to_fetch_for_w2 = days_to_fetch_for_w2
      @days_to_fetch_for_gig = days_to_fetch_for_gig
      @fetched_days = days_to_fetch_for_w2
    end

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
        @payroll_accounts.each do |payroll_account|
          fetch_report_data_for_account(payroll_account)
        end
      rescue StandardError => e
        Rails.logger.error("Report Fetch Error: #{e.message}")
        all_successful = false
      end
      @has_fetched = all_successful
    end

    AccountReportStruct = Struct.new(:identity, :income, :employment, :paystubs, :gigs)
    def find_account_report(account_id)
      AccountReportStruct.new(
        @identities.find { |identity| identity.account_id == account_id },
        @incomes.find { |income| income.account_id == account_id },
        @employments.find { |employment| employment.account_id == account_id },
        @paystubs.find_all { |paystub| paystub.account_id == account_id },
        @gigs.find_all { |gig| gig.account_id == account_id }
      )
    end

    def summarize_by_employer
      @payroll_accounts.each_with_object({}) do |payroll_account, hash|
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

    def summarize_by_month(from_date: nil, to_date: nil)
      from_date = parse_date_safely(self.from_date) if from_date.nil?
      to_date = parse_date_safely(self.to_date) if to_date.nil?

      @payroll_accounts
        .each_with_object({}) do |payroll_account, hash|
          account_id = payroll_account.pinwheel_account_id
          paystubs = @paystubs.filter { |paystub| paystub.account_id == account_id }
          gigs = @gigs.filter { |gig| gig.account_id == account_id }
          extracted_dates = extract_dates(paystubs, gigs)
          months = unique_months(extracted_dates)

          # Group paystubs and gigs by month
          hash[account_id] ||= months.each_with_object({}) do |month, result|
            month_string = month.strftime("%Y-%m")
            month_beginning = month.beginning_of_month
            month_end = month.end_of_month

            paystubs_in_month = paystubs.select { |paystub| parse_date_safely(paystub.pay_date)&.between?(month_beginning, month_end) }
            gigs_in_month = gigs.select { |gig| parse_date_safely(gig.end_date)&.between?(month_beginning, month_end) }
            extracted_dates_in_month = extract_dates(paystubs_in_month, gigs_in_month)

            result[month_string] = {
              paystubs: paystubs_in_month,
              gigs: gigs_in_month,
              accrued_gross_earnings: paystubs_in_month.sum { |paystub| paystub.gross_pay_amount || 0 },
              total_gig_hours: gigs_in_month.sum { |gig| gig.hours },
              partial_month_range: partial_month_details(month, extracted_dates_in_month, from_date, to_date)
            }
          end
        end
    end

    def total_gross_income
      @paystubs.reduce(0) { |sum, paystub| sum + (paystub.gross_pay_amount || 0) }
    end

    def days_since_last_paydate
      latest_paystub_date = paystubs.map(&:pay_date).compact.map { |pay_date| Date.parse(pay_date) }.max
      return nil if latest_paystub_date.nil?
      (Date.current - latest_paystub_date).to_i
    end

    def from_date
      @fetched_days.days.ago.to_date
    end

    def to_date
      # Use the CBV flow as the basis for the end of the report range, as it
      # reflects the actual time that the user was completing the flow (as
      # opposed to the invitation, which they could have been sitting on for
      # many days.)
      @payroll_accounts.first.cbv_flow.created_at.to_date
    end
  end
end

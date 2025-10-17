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
      account_employment = pick_employment(@employments, @paystubs, account_id)
      employment_filter = employment_filter_for(account_id, account_employment&.employment_matching_id)

      # Note that, once we filter by employment match, we do not yet have a good solution for displaying multiple
      # incomes or identities at this time. We just take the first.
      AccountReportStruct.new(
        @identities.filter(&employment_filter).first,
        @incomes.filter(&employment_filter).first,
        account_employment,
        @paystubs.filter(&employment_filter),
        @gigs.find_all { |gig| gig.account_id == account_id }
      )
    end

    def income_report
      {}.tap do |report|
        report[:has_other_jobs] = payroll_accounts.first.cbv_flow.has_other_jobs
        report[:employments] = summarize_by_employer.map do |_, summary|
          cbv_flow = payroll_accounts.first.cbv_flow
          {
            applicant_full_name: summary[:identity].full_name,
            applicant_ssn: summary[:identity].ssn,
            applicant_extra_comments: cbv_flow.additional_information["comment"],
            employer_name: summary[:employment].employer_name,
            employer_phone: summary[:employment].employer_phone_number,
            employer_address: summary[:employment]&.employer_address,
            employment_status: summary[:employment]&.status,
            employment_type: summary[:employment]&.employment_type,
            employment_start_date: summary[:employment]&.start_date,
            employment_end_date: summary[:employment]&.termination_date,
            pay_frequency: summary[:income]&.pay_frequency,
            compensation_amount: summary[:income]&.compensation_amount,
            compensation_unit: summary[:income]&.compensation_unit,
            paystubs: summary[:paystubs].map do |paystub|
              {
                pay_date: paystub.pay_date,
                pay_period_start: paystub.pay_period_start,
                pay_period_end: paystub.pay_period_end,
                pay_gross: paystub.gross_pay_amount,
                pay_gross_ytd: paystub.gross_pay_ytd,
                pay_net: paystub.net_pay_amount,
                hours_paid: paystub.hours
              }
            end
          }
        end
      end
    end

    def summarize_by_employer
      @payroll_accounts.each_with_object({}) do |payroll_account, hash|
        account_id = payroll_account.aggregator_account_id
        account_report = find_account_report(account_id)
        has_income_data = payroll_account.job_succeeded?("income")
        has_employment_data = payroll_account.job_succeeded?("employment")
        has_identity_data = payroll_account.job_succeeded?("identity")
        has_paystubs_data = payroll_account.job_succeeded?("paystubs")
        hash[account_id] ||= {
          total: account_report.paystubs.sum { |paystub| paystub.gross_pay_amount || 0 },
          has_income_data: has_income_data,
          has_employment_data: has_employment_data,
          has_identity_data: has_identity_data,
          employment: has_employment_data ? account_report.employment : nil,
          income: has_income_data ? account_report.income : nil,
          identity: has_identity_data ? account_report.identity : nil,
          paystubs: has_paystubs_data ? account_report.paystubs : nil,
          gigs: account_report.gigs
        }
      end
    end

    def summarize_by_month(from_date: nil, to_date: nil)
      from_date = parse_date_safely(self.from_date) if from_date.nil?
      to_date = parse_date_safely(self.to_date) if to_date.nil?

      @payroll_accounts
        .each_with_object({}) do |payroll_account, hash|
          account_id = payroll_account.aggregator_account_id
          account_report = find_account_report(account_id)
          paystubs = account_report.paystubs
          gigs = account_report.gigs
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
              total_gig_hours: gigs_in_month.sum { |gig| gig.hours || 0 },
              total_w2_hours: paystubs_in_month.sum { | paystub | paystub.hours.to_f },
              total_mileage: total_miles(gigs_in_month),
              partial_month_range: partial_month_details(month, extracted_dates_in_month, from_date, to_date)
            }
          end
        end
    end

    def total_miles(gigs)
      gigs.sum { |g| g.mileage || 0 }
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

    def fetched_days_for_account(account_id)
      account_employment = pick_employment(@employments, @paystubs, account_id)
      return @fetched_days unless account_employment

      case account_employment.employment_type
      when :gig
        @days_to_fetch_for_gig
      when :w2
        @days_to_fetch_for_w2
      else
        @fetched_days
      end
    end

    private

    def employment_filter_for(account_id, employment_matching_id)
      # Create a filter that filters any entities that don't match the account id and the employment id.
      # If the entity doesn't have an employment id, allow it (eg for Pinwheel)
      lambda do |item|
        item.account_id == account_id &&
          (item.employment_id.nil? || item.employment_id == employment_matching_id)
      end
    end

    def pick_employment(employments, paystubs, account_id)
      # In Argyle, the employments endpoint can return more than one employment.
      # This method chooses the employment we want to use. Later, we must filter related
      # data sets to make sure we're only using ones that match the employment ID we chose here.
      relevant_employments = employments.select { |e| e[:account_id] == account_id }
      if relevant_employments.empty?
        Rails.logger.error("No employments found that match account_id #{account_id}")
        raise "No employments found that match account_id #{account_id}"
      end

      # Pick the employment with the latest update when considering the start_date,
      # terminated_at, and any related paystub's pay_date properties.
      relevant_employments.max_by do |emp|
        relevant_paystubs = paystubs.select { |p| p[:employment_id] == emp.employment_matching_id }

        latest_pay_date = relevant_paystubs.map { |p| p[:pay_date] }.max

        dates = [
          emp[:start_date],
          emp[:termination_date],
          latest_pay_date
        ]

        dates.compact.max
      end
    end
  end
end

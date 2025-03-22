module Aggregators::AggregatorReports
  class PinwheelReport < AggregatorReport
    attr_accessor :pinwheel_service

    def initialize(payroll_accounts: [], pinwheel_service: nil, from_date: nil, to_date: nil)
      super(payroll_accounts: payroll_accounts, from_date: from_date, to_date: to_date)
      @pinwheel_service = pinwheel_service
    end
    private

    # TODO: bring this to abstract class
    def fetch_report_data
      all_successful = true
      @payroll_accounts.each do |account|
        begin
          fetch_report_data_for_account(account)
        rescue StandardError => e
          Rails.logger.error("Report Fetch Error: #{e.message}")
          all_successful = false
        end
      end
      @has_fetched = all_successful
    end

    def fetch_report_data_for_account(account)
      @identities.append(fetch_identity(account_id: account.pinwheel_account_id))
      @employments.append(fetch_employment(account_id: account.pinwheel_account_id))
      @incomes.append(fetch_income(account_id: account.pinwheel_account_id))
      @paystubs.append(*fetch_paystubs(account_id: account.pinwheel_account_id))
    end

    def fetch_paystubs(account_id:)
      # TODO: add @from_date and @to_date
      json = @pinwheel_service.fetch_paystubs_api(account_id: account_id)
      json["data"].map { |paystub_json| Aggregators::ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    end

    def fetch_employment(account_id:)
      json = @pinwheel_service.fetch_employment_api(account_id: account_id)
      Aggregators::ResponseObjects::Employment.from_pinwheel(json["data"])
    end

    def fetch_identity(account_id:)
      json = @pinwheel_service.fetch_identity_api(account_id: account_id)

      Aggregators::ResponseObjects::Identity.from_pinwheel(json["data"])
    end

    def fetch_income(account_id:)
      json = @pinwheel_service.fetch_income_api(account_id: account_id)

      Aggregators::ResponseObjects::Income.from_pinwheel(json["data"])
    end
  end
end

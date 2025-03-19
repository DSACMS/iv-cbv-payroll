module Aggregators::AggregatorReports
  class PinwheelReport < AggregatorReport
    def initialize(payroll_accounts: [], pinwheel_service:)
      puts("init_start")
      super(payroll_accounts: payroll_accounts)
      @pinwheel_service = pinwheel_service
      puts("init_end")
    end
    private

    def fetch_report_data
      puts("fetch_report_start")
      @payroll_accounts.each do |account|
        begin
          fetch_report_data_for_account(account)
        rescue StandardError => e
          Rails.logger.error("Report Fetch Error: #{e.message}")
          return @has_fetched = false
        end
      end
      @has_fetched = true
      puts("fetch_report_end")
    end

    def fetch_report_data_for_account(account)
      begin
        @identities.append(fetch_identity(account_id: account.pinwheel_account_id))
        @employments.append(fetch_employment(account_id: account.pinwheel_account_id))
        @incomes.append(fetch_income(account_id: account.pinwheel_account_id))
        @paystubs.append(fetch_paystubs(account_id: account.pinwheel_account_id))
      end
    end

    def transform_paystubs
      json = @pinhweel_service.fetch_paystubs_api
      json["data"].map { |paystub_json| Aggregators::ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    end

    def fetch_employment(account_id:)
      json = @pinhweel_service.fetch_employment_api(account_id: account_id)
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

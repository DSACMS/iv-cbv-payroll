module Aggregators::AggregatorReports
  class PinwheelReport < AggregatorReport
    def initialize(payroll_accounts: [], pinwheel_service:)
      super(payroll_accounts: payroll_accounts)
      @pinwheel_service = pinwheel_service
    end
    private


    def fetch_report_data_for_account(account, from_date: nil, to_date: nil)
      begin
        @identities.append(fetch_identity(account_id: account.pinwheel_account_id))
        @employments.append(fetch_employment(account_id: account.pinwheel_account_id))
        @incomes.append(fetch_income(account_id: account.pinwheel_account_id))
        @paystubs.append(*fetch_paystubs(account_id: account.pinwheel_account_id))
      end
    end

    def fetch_paystubs(account_id:)
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

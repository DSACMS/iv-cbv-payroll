module Aggregators::AggregatorReports
  class PinwheelReport < AggregatorReport
    attr_accessor :pinwheel_service

    def initialize(pinwheel_service: nil, **params)
      super(**params)
      @pinwheel_service = pinwheel_service
    end
    private

    def fetch_report_data_for_account(account)
      @identities.append(fetch_identity(account_id: account.pinwheel_account_id))
      @employments.append(fetch_employment(account_id: account.pinwheel_account_id))
      @incomes.append(fetch_income(account_id: account.pinwheel_account_id))
      @paystubs.append(*fetch_paystubs(account_id: account.pinwheel_account_id))
      @gigs.append(*fetch_gigs(account_id: account.pinwheel_account_id))
    end

    def fetch_paystubs(account_id:)
      json = @pinwheel_service.fetch_paystubs_api(account_id: account_id, from_pay_date: @from_date, to_pay_date: @to_date)
      json["data"].map { |paystub_json| Aggregators::ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    end

    def fetch_gigs(account_id:)
      json = @pinwheel_service.fetch_shifts_api(account_id: account_id)
      transform_gigs(json)
    end

    def transform_gigs(shifts_json)
      shifts_json["data"].map do |shift_json|
        Aggregators::ResponseObjects::Gig.from_pinwheel(shift_json)
      end
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

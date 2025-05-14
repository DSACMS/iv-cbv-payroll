module Aggregators::AggregatorReports
  class PinwheelReport < AggregatorReport
    include ActiveModel::Validations

    attr_accessor :pinwheel_service

    validates_with Aggregators::Validators::UsefulReportValidator, on: :useful_report

    def initialize(pinwheel_service: nil, **params)
      super(**params)
      @pinwheel_service = pinwheel_service
    end

    private

    def fetch_report_data_for_account(account)
      @identities.append(fetch_identity(account_id: account.pinwheel_account_id))
      @employments.append(fetch_employment(account_id: account.pinwheel_account_id))

      if account.job_succeeded?("income")
        @incomes.append(fetch_income(account_id: account.pinwheel_account_id))
      end

      @paystubs.append(*fetch_paystubs(account_id: account.pinwheel_account_id))
      @gigs.append(*fetch_gigs(account_id: account.pinwheel_account_id))
    end

    def fetch_account(account_id:)
      account_json = @pinwheel_service.fetch_account(account_id: account_id)
      account_json["data"]
    end

    def fetch_platform(account_id:)
      # Note: the fetch_platform call is only for additional analytics, so it's OK to fail.
      begin
        account_body = self.fetch_account(account_id: account_id)
        platform_json = @pinwheel_service.fetch_platform(platform_id: account_body["platform_id"])
        platform_json["data"]
      rescue StandardError => e
        Rails.logger.error "Failed to fetch platform: #{e.message}"
        nil
      end
    end

    def fetch_paystubs(account_id:)
      json = @pinwheel_service.fetch_paystubs_api(account_id: account_id, from_pay_date: @from_date, to_pay_date: @to_date)
      json["data"].map { |paystub_json| Aggregators::ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    end

    def fetch_gigs(account_id:)
      gigs_json = @pinwheel_service.fetch_shifts_api(account_id: account_id)
      gigs_json["data"].map { |gig_json| Aggregators::ResponseObjects::Gig.from_pinwheel(gig_json) }
    end

    def fetch_employment(account_id:)
      platform_body = fetch_platform(account_id: account_id)

      json = @pinwheel_service.fetch_employment_api(account_id: account_id)
      Aggregators::ResponseObjects::Employment.from_pinwheel(json["data"], platform_body)
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

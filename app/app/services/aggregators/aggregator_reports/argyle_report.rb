module Aggregators::AggregatorReports
  class ArgyleReport < AggregatorReport
    include Aggregators::ResponseObjects

    def initialize(payroll_accounts: [], argyle_service:)
      super(payroll_accounts: payroll_accounts)
      @argyle_service = argyle_service
    end

    def is_ready_to_fetch?
      true
    end

    def fetch
      begin
        identities_json = @argyle_service.fetch_identities_api
        paystubs_json = @argyle_service.fetch_paystubs_api

        @identities = transform_identities(identities_json)
        @employments = transform_employments(identities_json)
        @incomes =  transform_incomes(identities_json)
        @paystubs = transform_paystubs(paystubs_json)

        @has_fetched = true
      rescue StandardError => e
        debugger
        Rails.logger.error("Report Fetch Error: #{e.message}")
        @has_fetched = false
      end

      @has_fetched
    end

    def transform_identities(identities_json)
      identities_json["results"].map do |identity_json|
        Identity.from_argyle(identity_json)
      end
    end

    def transform_employments(identities_json)
      identities_json["results"].map do |identity_json|
        Employment.from_argyle(identity_json)
      end
    end

    def transform_incomes(identities_json)
      identities_json["results"].map do |identity_json|
        Income.from_argyle(identity_json)
      end
    end

    def transform_paystubs(paystubs_json)
      paystubs_json["results"].map do |paystub_json|
        Paystub.from_argyle(paystub_json)
      end
    end
  end
end

module Aggregators
  class ArgyleReport < AggregatorReport
    def fetch
      return false unless is_ready_to_fetch?

      begin
        identities_json = fetch_identities_api(account: account, **params)
        paystubs_json = fetch_paystubs_api(account: account, **params)

        @identity = transform_identity(identities_json),
        @employments = transform_employments(identities_json),
        @incomes =  transform_incomes(identities_json),
        @paystubs = transform_paystubs(paystubs_json)

        @has_fetched = true
      rescue StandardError => e
        Rails.logger.error("Report Fetch Error: #{e.message}")
        @has_fetched = false
      end

      @has_fetched
    end

    private

    def transform_identity(identity_json)
      Aggregators::ResponseObjects::Identity.from_argyle(identities_json["results"][0])
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

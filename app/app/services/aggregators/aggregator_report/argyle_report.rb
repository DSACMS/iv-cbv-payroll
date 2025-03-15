module Aggregators
  class ArgyleReport < AggregatorReport
    def fetch
      begin
        identities_json = fetch_identities_api(account: account, **params)
        paystubs_json = fetch_paystubs_api(account: account, **params)

        @identity = Aggregators::ResponseObjects::Identity.from_argyle(identities_json["results"][0]),
        @employments = identities_json["results"].map { |identity_json| Employment.from_argyle(identity_json) },
        @incomes =  identities_json["results"].map { |identity_json| Income.from_argyle(identity_json) },
        @paystubs = paystubs_json["results"].map { |paystub_json| Paystub.from_argyle(paystub_json) }

        @has_fetched = true
        @has_fetched
      rescue StandardError => e
        Rails.logger.error("Report Fetch Error: #{e.message}")
        @has_fetched = false
        @has_fetched
      end
    end
  end
end

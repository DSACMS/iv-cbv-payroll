module Aggregators::AggregatorReports
  class ArgyleReport < AggregatorReport
    include Aggregators::ResponseObjects

    def initialize(argyle_service: nil, **params)
      super(**params)
      @argyle_service = argyle_service
    end

    private
    def fetch_report_data_for_account(account)
      identities_json = @argyle_service.fetch_identities_api(account: account)
      paystubs_json = @argyle_service.fetch_paystubs_api(account: account, from_start_date: @from_date, to_start_date: @to_date)

      @identities.append(*transform_identities(identities_json))
      @employments.append(*transform_employments(identities_json))
      @incomes.append(*transform_incomes(identities_json))
      @paystubs.append(*transform_paystubs(paystubs_json))
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

module Aggregators::AggregatorReports
  class ArgyleReport < AggregatorReport
    include Aggregators::ResponseObjects
    include ActiveModel::Validations

    validates_with Aggregators::Validators::UsefulReportValidator, on: :useful_report

    def initialize(argyle_service: nil, **params)
      super(**params)
      @argyle_service = argyle_service
    end

    private

    def fetch_report_data_for_account(payroll_account)
      identities_json = @argyle_service.fetch_identities_api(
        account: payroll_account.pinwheel_account_id
      )

      # Override the date range to fetch when fetching a gig job.
      has_gig_job = identities_json["results"].any? do |identity_json|
        Aggregators::FormatMethods::Argyle.employment_type(identity_json["employment_type"]) == :gig
      end
      if has_gig_job
        @fetched_days = @days_to_fetch_for_gig
      end

      account_json = @argyle_service.fetch_account_api(
        account: payroll_account.pinwheel_account_id
      )
      paystubs_json = @argyle_service.fetch_paystubs_api(
        account: payroll_account.pinwheel_account_id,
        from_start_date: from_date,
        to_start_date: to_date
      )
      gigs_json = @argyle_service.fetch_gigs_api(
        account: payroll_account.pinwheel_account_id,
        from_start_datetime: from_date,
        to_start_datetime: to_date
      )

      @identities.append(*transform_identities(identities_json))
      @employments.append(*transform_employments(identities_json,
                                                 ArgyleReport.most_recent_paystub_with_address(paystubs_json),
                                                 account_json))
      @incomes.append(*transform_incomes(identities_json))
      @paystubs.append(*transform_paystubs(paystubs_json))
      @gigs.append(*transform_gigs(gigs_json))
    end

    def transform_identities(identities_json)
      identities_json["results"].map do |identity_json|
        Identity.from_argyle(identity_json)
      end
    end

    def transform_employments(identities_json, a_paystub_json, account_json)
      identities_json["results"].map do |identity_json|
        Employment.from_argyle(identity_json, a_paystub_json, account_json)
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

    def self.most_recent_paystub_with_address(paystubs_json)
      # Filter and sort to find the most recent valid paystub
      paystubs_json["results"]
        .select { |paystub_json| paystub_json.dig("employer_address", "line1").present? }
        .max_by { |paystub_json| Date.parse(paystub_json["paystub_date"]) rescue Date.new(0) }
    end

    def transform_gigs(gigs_json)
      gigs_json["results"].map do |gig_json|
        Gig.from_argyle(gig_json)
      end
    end
  end
end

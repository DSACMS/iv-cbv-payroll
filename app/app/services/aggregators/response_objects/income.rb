module Aggregators::ResponseObjects
  INCOME_FIELDS = %i[
    account_id
    pay_frequency
    compensation_amount
    compensation_unit
    employment_id
  ]

  Income = Struct.new(*INCOME_FIELDS, keyword_init: true) do
    FREQUENCY_NORMALIZATION = {
      "bi-weekly" => "biweekly",
      "semi-monthly" => "semimonthly",
      "annually" => "annual",
      "semi-weekly" => "semiweekly"
    }.freeze

    def self.from_pinwheel(response_body)
      new(
        account_id: response_body["account_id"],
        pay_frequency: normalize(response_body["pay_frequency"]),
        compensation_amount: response_body["compensation_amount"],
        compensation_unit: normalize(response_body["compensation_unit"]),
        employment_id: nil
      )
    end

    def self.from_argyle(identities_response_body)
      new(
        account_id: identities_response_body["account"],
        pay_frequency: identities_response_body["pay_cycle"],
        compensation_amount: Aggregators::FormatMethods::Argyle.format_currency(
          identities_response_body["base_pay"]["amount"]
        ),
        compensation_unit: identities_response_body["base_pay"]["period"],
        employment_id: identities_response_body["employment"]
      )
    end

    private

    def self.normalize(value)
      return nil if value.blank?

      FREQUENCY_NORMALIZATION[value.downcase] || value
    end
  end
end

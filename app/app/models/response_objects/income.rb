INCOME_FIELDS = %i[
  account_id
  pay_frequency
  compensation_amount
  compensation_unit
]

module ResponseObjects
  Income = Struct.new(*INCOME_FIELDS, keyword_init: true) do
    def self.from_pinwheel(response_body)
      new(
        account_id: response_body["account_id"],
        pay_frequency: response_body["pay_frequency"],
        compensation_amount: response_body["compensation_amount"],
        compensation_unit: response_body["compensation_unit"],
      )
    end
    def self.from_argyle(identities_response_body)
      new(
        account_id: identities_response_body["account"],
        pay_frequency: identities_response_body["base_pay"]["period"],
        compensation_amount: ArgyleMethods.format_currency(identities_response_body["base_pay"]["amount"]),
        compensation_unit: identities_response_body["base_pay"]["currency"],
      )
    end
  end

  module ArgyleMethods
    def self.format_currency(amount)
      return unless amount
      amount.to_f
    end
  end
end

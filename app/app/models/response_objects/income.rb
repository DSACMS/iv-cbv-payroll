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
  end
end

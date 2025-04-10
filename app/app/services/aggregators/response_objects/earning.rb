module Aggregators::ResponseObjects
  EARNING_FIELDS = %i[
    amount
    category
    hours
    name
    rate
  ]

  Earning = Struct.new(*EARNING_FIELDS, keyword_init: true) do
    def self.from_pinwheel(earning_entry)
      new(
        amount: earning_entry["amount"],
        category: earning_entry["category"],
        hours: earning_entry["hours"],
        rate: earning_entry["rate"],
        name: earning_entry["name"],
      )
    end

    def self.from_argyle(earning_entry)
      new(
        amount: Aggregators::FormatMethods::Argyle.format_currency(
          earning_entry["amount"]
        ),
        category: earning_entry["type"],
        hours: earning_entry["hours"],
        rate: earning_entry["rate"],
        name: earning_entry["name"],
      )
    end
  end
end

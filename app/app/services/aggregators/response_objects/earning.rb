module Aggregators::ResponseObjects
  EARNING_FIELDS = %i[
    amount
    category
    hours
    name
    rate
  ]

  Earning = Struct.new(*EARNING_FIELDS, keyword_init: true) do
    def self.from_pinwheel(item)
      new(
        amount: item["amount"],
        category: item["category"],
        hours: item["hours"],
        rate: item["rate"],
        name: item["name"],
      )
    end

    def self.from_argyle(item)
      new(
        amount: Aggregators::FormatMethods::Argyle.format_currency(
          item["amount"]
        ),
        category: item["type"],
        hours: item["hours"],
        rate: item["rate"],
        name: item["name"],
      )
    end
  end
end

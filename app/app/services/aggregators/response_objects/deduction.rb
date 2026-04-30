module Aggregators::ResponseObjects
  DEDUCTION_FIELDS = %i[
    category
    tax
    amount
  ]

  Deduction = Struct.new(*DEDUCTION_FIELDS, keyword_init: true) do
    def self.from_pinwheel(deduction_entry)
      new(
        category: deduction_entry["category"],
        tax: deduction_entry["type"] || "unknown",
        amount: deduction_entry["amount"]
      )
    end

    def self.from_argyle(deduction_entry)
      new(
        category: deduction_entry["name"],
        tax: deduction_entry["tax_classification"] || "unknown",
        amount: Aggregators::FormatMethods::Argyle.format_currency(deduction_entry["amount"])
      )
    end
  end
end

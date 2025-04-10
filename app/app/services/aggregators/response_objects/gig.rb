GIG_FIELDS = %i[
  account_id
  gig_type
  gig_status
  hours
  start_date
  end_date
  compensation_category
  compensation_amount
  compensation_unit
]

module Aggregators::ResponseObjects
  Gig = Struct.new(*GIG_FIELDS, keyword_init: true) do
    def self.from_argyle(response_body)
      new(
        account_id: response_body["account"],
        gig_type: response_body["type"],
        gig_status: response_body["status"],
        hours: Aggregators::FormatMethods::Argyle.seconds_to_hours(response_body["duration"]),
        start_date: Aggregators::FormatMethods::Argyle.format_date(response_body["start_datetime"]),
        end_date: Aggregators::FormatMethods::Argyle.format_date(response_body["end_datetime"]),
        compensation_category: response_body["earning_type"],
        compensation_amount: Aggregators::FormatMethods::Argyle.format_currency(response_body["income"]["pay"]),
        compensation_unit: response_body["income"]["currency"]
      )
    end

    def self.from_pinwheel(response_body)
      new(
        account_id: response_body["account_id"],
        gig_type: response_body["type"],
        gig_status: nil, # pinwheel shifts don't have status
        hours: Aggregators::FormatMethods::Pinwheel.hours(response_body["earnings"]),
        start_date: response_body["start_date"],
        end_date: response_body["end_date"],
        compensation_category: response_body["earnings"].first["category"],
        compensation_amount: response_body["earnings"].first["amount"], # Pinwheel already provides amounts in cents
        compensation_unit: response_body["currency"]
      )
    end
  end
end

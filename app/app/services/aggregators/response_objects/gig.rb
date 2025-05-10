GIG_FIELDS = %i[
  account_id
  gig_type
  gig_status
  hours
  start_date
  end_date
  compensation_category
  compensation_amount
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
        compensation_amount: Aggregators::FormatMethods::Argyle.format_currency(response_body["income"]["pay"])
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
        compensation_amount: Aggregators::FormatMethods::Pinwheel.total_earnings_amount(response_body["earnings"])
      )
    end
  end
end

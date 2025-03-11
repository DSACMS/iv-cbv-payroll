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

def seconds_to_hours(seconds)
  return unless seconds
  seconds / 3600
end

module ResponseObjects
  Gig = Struct.new(*GIG_FIELDS, keyword_init: true) do
    def self.from_pinwheel(response_body)
    end


    def self.from_argyle(response_body)
      new(
        account_id: response_body["account"],
        gig_type: response_body["type"],
        gig_status: response_body["status"],
        hours: ArgyleFormat.seconds_to_hours(response_body["duration"]),
        start_date: ArgyleFormat.format_date(response_body["start_datetime"]),
        end_date: ArgyleFormat.format_date(response_body["end_datetime"]),
        compensation_category: response_body["earning_type"],
        compensation_amount: ArgyleFormat.format_currency(response_body["income"]["pay"]),
        compensation_unit: response_body["income"]["currency"]
      )
    end
  end
  module ArgyleFormat
    def self.format_employment_status(employment_status)
      return unless employment_status

      case employment_status
      when "active"
        "employed"
      when "inactive"
        "furloughed"
      else
        employment_status
      end
    end

    def self.format_date(date)
      return unless date

      DateTime.parse(date).strftime("%Y-%m-%d")
    end

    def self.format_currency(amount)
      return unless amount
      amount.to_f
    end

    def self.hours_by_earning_category(gross_pay_list)
      gross_pay_list
        .filter { |e| e["hours"].present? }
        .group_by { |e| e["type"] }
        .transform_values { |earnings| earnings.sum { |e| e["hours"].to_f } }
    end

    def self.seconds_to_hours(seconds)
      return unless seconds
      (seconds.to_f / 3600).round(2)
    end
  end
end

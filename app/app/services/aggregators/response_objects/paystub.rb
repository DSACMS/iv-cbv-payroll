PAYSTUB_FIELDS = %i[
  account_id
  gross_pay_amount
  net_pay_amount
  gross_pay_ytd
  pay_period_start
  pay_period_end
  pay_date
  deductions
  hours_by_earning_category
  hours
]

module Aggregators::ResponseObjects
  Paystub = Struct.new(*PAYSTUB_FIELDS, keyword_init: true) do
    def self.from_pinwheel(response_body)
      new(
        account_id: response_body["account_id"],
        gross_pay_amount: response_body["gross_pay_amount"],
        net_pay_amount: response_body["net_pay_amount"],
        gross_pay_ytd: response_body["gross_pay_ytd"],
        pay_period_start: response_body["pay_period_start"],
        pay_period_end: response_body["pay_period_end"],
        pay_date: response_body["pay_date"],
        hours: Aggregators::FormatMethods::Pinwheel.hours(response_body["earnings"]),
        hours_by_earning_category: Aggregators::FormatMethods::Pinwheel.hours_by_earning_category(response_body["earnings"]),
        deductions: Aggregators::FormatMethods::Pinwheel.format_deductions(response_body["deductions"]),
      )
    end

    def self.from_argyle(response_body)
      new(
        account_id: response_body["account"],
        gross_pay_amount: Aggregators::FormatMethods::Argyle.format_currency(response_body["gross_pay"]),
        net_pay_amount: Aggregators::FormatMethods::Argyle.format_currency(response_body["net_pay"]),
        gross_pay_ytd: Aggregators::FormatMethods::Argyle.format_currency(response_body["gross_pay_ytd"]),
        pay_period_start: Aggregators::FormatMethods::Argyle.format_date(response_body.dig("paystub_period", "start_date")),
        pay_period_end: Aggregators::FormatMethods::Argyle.format_date(response_body.dig("paystub_period", "end_date")),
        pay_date: Aggregators::FormatMethods::Argyle.format_date(response_body["paystub_date"]),
        hours: response_body["hours"],
        hours_by_earning_category: Aggregators::FormatMethods::Argyle.hours_by_earning_category(response_body["gross_pay_list"]),
        deductions: Aggregators::FormatMethods::Argyle.format_deductions(response_body["deduction_list"])
      )
    end

    def earnings_meet_requirements?
      true
    end

    def meets_requirements?
      self.pay_date.present? &&
      self.pay_period_start.present? &&
      self.pay_period_end.present? &&
      self.gross_pay_amount.present? &&
      self.hours.present? &&
      self.earnings_meet_requirements?
    end

    alias_attribute :start, :pay_period_start
    alias_attribute :end, :pay_period_end
  end
end

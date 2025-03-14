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

module ResponseObjects
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
        hours: ResponseObjects::FormatMethods::Pinwheel.hours(response_body["earnings"]),
        hours_by_earning_category: ResponseObjects::FormatMethods::Pinwheel.hours_by_earning_category(response_body["earnings"]),
        deductions: response_body["deductions"].map do |deduction|
          OpenStruct.new(
            category: deduction["category"],
            amount: deduction["amount"],
          )
        end,
      )
    end


    def self.from_argyle(response_body)
      new(
        account_id: response_body["account"],
        gross_pay_amount: ResponseObjects::FormatMethods::Argyle.format_currency(response_body["gross_pay"]),
        net_pay_amount: ResponseObjects::FormatMethods::Argyle.format_currency(response_body["net_pay"]),
        gross_pay_ytd: ResponseObjects::FormatMethods::Argyle.format_currency(response_body["gross_pay_ytd"]),
        pay_period_start: ResponseObjects::FormatMethods::Argyle.format_date(response_body["paystub_period"]["start_date"]),
        pay_period_end: ResponseObjects::FormatMethods::Argyle.format_date(response_body["paystub_period"]["end_date"]),
        pay_date: ResponseObjects::FormatMethods::Argyle.format_date(response_body["paystub_date"]),
        hours: response_body["hours"],
        hours_by_earning_category: ResponseObjects::FormatMethods::Argyle.hours_by_earning_category(response_body["gross_pay_list"]),
        deductions: response_body["deduction_list"].map do |deduction|
          OpenStruct.new(
            category: deduction["name"],
            amount: ResponseObjects::FormatMethods::Argyle.format_currency(deduction["amount"]),
          )
        end,
      )
    end

    alias_attribute :start, :pay_period_start
    alias_attribute :end, :pay_period_end
  end
end

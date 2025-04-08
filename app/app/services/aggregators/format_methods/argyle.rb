module Aggregators::FormatMethods::Argyle
  # Note: this method is to map Argyle's employment status with Pinwheel's for consistency
  # between the two providers.
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
    return unless date.present?

    DateTime.parse(date).strftime("%Y-%m-%d")
  end

  def self.format_currency(amount)
    return unless amount
    amount.to_f
  end

  def self.hours_by_earning_category(gross_pay_list)
    return unless  gross_pay_list.kind_of? Array
    gross_pay_list
       .filter { |e| e["hours"].present? }
       .group_by { |e| e["type"] }
       .transform_values { |earnings| earnings.sum { |e| e["hours"].to_f } }
  end

  def self.format_deductions(deductions_list)
    return unless  deductions_list.kind_of? Array
    deductions_list.map do |deduction|
      OpenStruct.new(
        category: deduction["name"],
        amount: Aggregators::FormatMethods::Argyle.format_currency(deduction["amount"]),
        )
    end
  end
end

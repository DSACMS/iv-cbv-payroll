module ArgyleFormatMethods
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
    seconds / 3600
  end
end

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
    return unless date

    DateTime.parse(date).strftime("%Y-%m-%d")
  end

  def self.format_currency(amount)
    return unless amount
    dollars, cents = amount.split(".").map(&:to_i)

    (dollars * 100) + cents
  end

  def self.hours_by_earning_category(gross_pay_list)
    gross_pay_list
       .filter { |e| e["hours"].present? }
       .group_by { |e| e["type"] }
       .transform_values { |earnings| earnings.sum { |e| e["hours"].to_f } }
  end

  def self.format_employer_address(a_paystub)
    return unless a_paystub.present? && a_paystub["employer_address"].present?
    employer_address = a_paystub["employer_address"]
    [
      employer_address["line1"],
      employer_address["line2"],
      "#{employer_address['city']}, #{employer_address['state']} #{employer_address['postal_code']}"
    ].compact.join(", ")
  end

  def self.seconds_to_hours(seconds)
    return unless seconds
    (seconds / 3600.0).round(2)
  end

  def self.employment_type(employment_type)
    if employment_type == "contractor"
      :gig
    else
      :w2
    end
  end
end

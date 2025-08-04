module Aggregators::FormatMethods::Argyle
  MILES_PER_KM = 0.62137

  # Note: this method is to map Argyle's employment status with Pinwheel's for consistency
  # between the two providers.
  def self.format_employment_status(employment_status)
    return unless employment_status

    case employment_status
    when "active"
      "employed"
    else
      employment_status
    end
  end

  def self.format_mileage(distance_string, distance_unit = "miles")
    return nil if distance_string.blank?
    distance = distance_string.to_f
    if distance_unit == "km"
      distance = distance * MILES_PER_KM
    end
    distance
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

  def self.hours_computed(response_hours, response_gross_pay_list)
    if response_hours.present? && response_hours.to_f > 0
      response_hours.to_f
    else
      hours_by_earning_category(response_gross_pay_list).map { |_category, hours| hours.to_f }.max
    end
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

  def self.obfuscate_ssn(full_ssn)
    return unless full_ssn
    "XXX-XX-#{full_ssn.last(4).to_s.rjust(4, "X")}"
  end
end

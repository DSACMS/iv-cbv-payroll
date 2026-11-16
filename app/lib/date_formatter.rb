class DateFormatter
  def self.parse(value)
    if value.is_a?(Hash)
      day = value["day"].to_i
      month = value["month"].to_i
      year = value["year"].to_i

      return unless month.between?(1, 12) && day.between?(1, 31) && year.positive?
      return unless Date.valid_date?(year, month, day)

      Date.new(year, month, day)
    else
      datify(value)
    end
  end

  def self.parse_month_year(value)
    return if value.blank?

    if (match = value.match(/\A(?<month>0?[1-9]|1[0-2])\/(?<year>\d{4})\z/))
      year = match[:year].to_i
      month = match[:month].to_i
      Date.new(year, month, 1) if year.positive?
    end
  end

  private

  def self.datify(value)
    return value if value.is_a?(Date)
    return unless value.is_a?(String) && value.present?

    if value.match?(%r{\A\d{2}/\d{2}/\d{4}\z})
      month, day, year = value.split("/").map(&:to_i)
      Date.new(year, month, day) if Date.valid_date?(year, month, day)
    elsif value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      year, month, day = value.split("-").map(&:to_i)
      Date.new(year, month, day) if Date.valid_date?(year, month, day)
    end
  end
end

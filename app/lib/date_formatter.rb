class DateFormatter
  def self.parse(value)
    if value.is_a?(Hash)
      day = value["day"].to_i
      month = value["month"].to_i
      year = value["year"].to_i
      Date.new(year, month, day) rescue nil
    else
      datify(value)
    end
  end

  private

  def self.datify(value)
    return value if value.is_a?(Date)

    if value.is_a?(String) && value.present?
      begin
        Date.strptime(value, "%m/%d/%Y")
      rescue ArgumentError
        nil
      end
    end
  end
end

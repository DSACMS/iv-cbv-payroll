module PinwheelFormatMethods
  def self.hours(earnings)
    base_hours = earnings
      .filter { |e| e["category"] != "overtime" }
      .map { |e| e["hours"] }
      .compact
      .max
    return unless base_hours

    # Add overtime hours to the base hours, because they tend to be additional
    # work beyond the other entries. (As opposed to category="premium", which
    # often duplicates other earnings' hours.)
    #
    # See FFS-1773.
    overtime_hours = earnings
      .filter { |e| e["category"] == "overtime" }
      .sum { |e| e["hours"] || 0.0 }

    base_hours + overtime_hours
  end

  def self.hours_by_earning_category(earnings)
    earnings
      .filter { |e| e["hours"] && e["hours"] > 0 }
      .group_by { |e| e["category"] }
      .transform_values { |earnings| earnings.sum { |e| e["hours"] } }
  end
end

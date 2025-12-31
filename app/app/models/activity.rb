class Activity < ApplicationRecord
  self.abstract_class = true

  belongs_to :activity_flow

  validate :date_within_reporting_month

  def date=(value)
    self[:date] = DateFormatter.parse(value)
  end

  private

  def date_within_reporting_month
    return if date.blank? || activity_flow&.reporting_month.blank?

    unless activity_flow.reporting_month_range.cover?(date)
      errors.add(:date, :outside_reporting_month,
        month: activity_flow.reporting_month_display)
    end
  end
end

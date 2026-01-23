class Activity < ApplicationRecord
  self.abstract_class = true

  belongs_to :activity_flow

  validate :date_within_reporting_window

  def date=(value)
    self[:date] = DateFormatter.parse(value)
  end

  private

  def date_within_reporting_window
    return if date.blank? || activity_flow.blank?

    unless activity_flow.reporting_window_range.cover?(date)
      errors.add(:date, :outside_reporting_window,
        range: activity_flow.reporting_window_display)
    end
  end
end

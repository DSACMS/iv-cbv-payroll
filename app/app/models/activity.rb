class Activity < ApplicationRecord
  self.abstract_class = true

  belongs_to :activity_flow

  enum :data_source, { self_attested: "self_attested", validated: "validated" }, default: :self_attested

  scope :published, -> { where(draft: false) }

  def publish!
    update!(draft: false)
  end

  validate :date_within_reporting_window

  def date=(value)
    return unless has_attribute?(:date)

    self[:date] = DateFormatter.parse(value)
  end

  private

  def date_within_reporting_window
    return unless has_attribute?(:date)
    return if date.blank? || activity_flow.blank?

    unless activity_flow.reporting_window_range.cover?(date)
      errors.add(:date, :outside_reporting_window,
        range: activity_flow.reporting_window_display)
    end
  end
end

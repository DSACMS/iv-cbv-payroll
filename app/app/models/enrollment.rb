class Enrollment < ApplicationRecord
  belongs_to :school
  belongs_to :education_activity, optional: true

  enum :status, { full_time: "full_time",
                  part_time: "part_time",
                  quarter_time: "quarter_time" }

  scope :current, -> do
    where(semester_start: Date.today.prev_month(6)..Date.today.next_month(6))
  end

  def less_than_part_time?
    self.quarter_time?
  end

  def current?
    (Date.today.prev_month(6)..Date.today.next_month(6)).include?(self.semester_start)
  end
end

class School < ApplicationRecord
  belongs_to :identity
  has_many :enrollments

  def most_recent_enrollment
    self.enrollments.order(semester_start: :desc).limit(1)[0]
  end

  def current_enrollments
    self.enrollments.merge Enrollment.current
  end
end

class School < ApplicationRecord
  belongs_to :identity
  has_many :enrollments, dependent: :destroy

  def most_recent_enrollment
    self.enrollments.order(semester_start: :desc).limit(1)[0]
  end

  def current_enrollments
    self.enrollments.merge Enrollment.current
  end

  def current?
    self.most_recent_enrollment&.current?
  end
end

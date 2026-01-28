class NscEnrollmentTerm < ApplicationRecord
  belongs_to :education_activity

  enum :enrollment_status, {
    full_time: "full_time",                     # F
    three_quarter_time: "three_quarter_time",   # Q
    half_time: "half_time",                     # H
    less_than_half_time: "less_than_half_time", # L
    enrolled: "enrolled",                       # Y
    unknown: "unknown"
  }, default: :unknown, prefix: :enrollment
end

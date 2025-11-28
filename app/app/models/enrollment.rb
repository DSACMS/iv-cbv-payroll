class Enrollment < ApplicationRecord
  belongs_to :school
  enum :status, :full_time => "full", :part_time => "part", :quarter_time => "quarter"

  def less_than_part_time?

  end
end

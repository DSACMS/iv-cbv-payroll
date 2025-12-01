class VolunteeringActivity < ApplicationRecord
  belongs_to :activity_flow

  def date=(value)
    self[:date] = DateFormatter.parse(value)
  end
end

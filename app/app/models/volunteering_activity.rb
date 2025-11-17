class VolunteeringActivity < ApplicationRecord
  def date=(value)
    self[:date] = DateFormatter.parse(value)
  end
end

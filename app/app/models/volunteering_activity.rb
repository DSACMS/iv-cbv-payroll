class VolunteeringActivity < Activity
  has_many :volunteering_activity_months, dependent: :destroy
end

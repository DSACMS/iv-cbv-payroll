class VolunteeringActivity < Activity
  include HasActivityMonths

  has_many :volunteering_activity_months, dependent: :destroy
  has_activity_months :volunteering_activity_months
end

class VolunteeringActivity < Activity
  include HasActivityMonths

  has_many :volunteering_activity_months, dependent: :destroy
  has_activity_months :volunteering_activity_months

  def formatted_address
    locality = [ city, state ].compact_blank.join(", ")
    locality_zip = [ locality.presence, zip_code.presence ].compact.join(" ")
    [ street_address, street_address_line_2.presence, locality_zip.presence ].compact.join(", ")
  end
end

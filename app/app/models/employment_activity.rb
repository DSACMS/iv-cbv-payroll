class EmploymentActivity < Activity
  include HasActivityMonths

  has_many :employment_activity_months, dependent: :destroy
  has_activity_months :employment_activity_months

  # No date column -- skip the inherited date validation from Activity
  def date_within_reporting_window; end

  def formatted_address
    locality = [ city, state ].compact_blank.join(", ")
    locality_zip = [ locality, zip_code ].compact_blank.join(" ")
    [ street_address, street_address_line_2, locality_zip ].compact_blank.join(", ")
  end
end

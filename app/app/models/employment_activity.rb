class EmploymentActivity < Activity
  include HasActivityMonths

  has_many :employment_activity_months, dependent: :destroy
  has_activity_months :employment_activity_months

  validates :employer_name, presence: { message: I18n.t("activities.employment_info.employer_name_error") }

  before_save :clear_contact_fields_if_self_employed

  # No date column -- skip the inherited date validation from Activity
  def date_within_reporting_window; end

  def clear_contact_fields_if_self_employed
    if is_self_employed
      self.contact_name = nil
      self.contact_email = nil
      self.contact_phone_number = nil
    end
  end

  def formatted_address
    locality = [ city, state ].compact_blank.join(", ")
    locality_zip = [ locality, zip_code ].compact_blank.join(" ")
    [ street_address, street_address_line_2, locality_zip ].compact_blank.join(", ")
  end
end

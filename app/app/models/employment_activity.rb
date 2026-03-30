class EmploymentActivity < Activity
  include HasActivityMonths
  include DocumentUploadable

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

  def document_upload_object_title
    employer_name
  end

  def document_upload_months_to_verify
    employment_activity_months.map(&:month)
  end

  def document_upload_details_for_month(month)
    activity_month = employment_activity_months
      .find { |employment_activity_month| employment_activity_month.month == month }

    return unless activity_month

    I18n.t(
      "activities.employment.document_upload_month_detail",
      gross_income: ActiveSupport::NumberHelper.number_to_currency(activity_month.gross_income),
      hours: I18n.t("shared.hours", count: activity_month.hours)
    )
  end

  def document_upload_suggestion_text
    "activities.employment.document_upload_suggestion_text_html"
  end
end

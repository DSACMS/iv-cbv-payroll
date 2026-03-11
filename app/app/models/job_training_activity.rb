class JobTrainingActivity < Activity
  include HasActivityMonths
  include DocumentUploadable

  validates :organization_name, :program_name, presence: true

  has_many :job_training_activity_months, dependent: :destroy
  has_activity_months :job_training_activity_months

  def formatted_address
    locality = [ city, state ].compact_blank.join(", ")
    locality_zip = [ locality, zip_code ].compact_blank.join(" ")
    [ street_address, street_address_line_2, locality_zip ].compact_blank.join(", ").presence || organization_address.presence
  end

  def document_upload_object_title
    program_name
  end

  def document_upload_months_to_verify
    job_training_activity_months.map(&:month)
  end

  def document_upload_details_for_month(month)
    month_record = job_training_activity_months
      .find { |activity_month| activity_month.month == month }

    I18n.t("shared.hours", count: month_record.hours) if month_record
  end

  def document_upload_suggestion_text
    "activities.job_training.document_upload_suggestion_text_html"
  end
end

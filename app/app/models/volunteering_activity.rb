class VolunteeringActivity < Activity
  include HasActivityMonths
  include DocumentUploadable

  has_many :volunteering_activity_months, dependent: :destroy
  has_activity_months :volunteering_activity_months

  def formatted_address
    locality = [ city, state ].compact_blank.join(", ")
    locality_zip = [ locality, zip_code ].compact_blank.join(" ")
    [ street_address, street_address_line_2, locality_zip ].compact_blank.join(", ")
  end

  def document_upload_object_title
    organization_name
  end

  def document_upload_months_to_verify
    volunteering_activity_months.map(&:month)
  end

  def document_upload_details_for_month(month)
    activity_month = volunteering_activity_months
      .find { |activity_month| activity_month.month == month }

    I18n.t("shared.hours", count: activity_month.hours) if activity_month
  end

  def document_upload_suggestion_text
    I18n.t("activities.community_service.document_upload_suggestion_text_html")
  end
end

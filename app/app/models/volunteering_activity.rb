class VolunteeringActivity < Activity
  include HasActivityMonths
  include DocumentUploadable

  has_many :volunteering_activity_months, dependent: :destroy
  has_activity_months :volunteering_activity_months

  def document_upload_object_title
    organization_name
  end

  def document_upload_months_to_verify
    # TODO: Use the proper months when we allow looping through volunteer hours
    # input pages.
    Array(date.beginning_of_month)
  end

  def document_upload_details_for_month(month)
    # TODO: Use the proper hours for each month when we allow looping through
    # volunteer hours input pages.
    I18n.t("shared.hours", count: hours) if month.all_month.include?(date)
  end

  def document_upload_suggestion_text
    I18n.t("activities.community_service.document_upload_suggestion_text_html")
  end
end

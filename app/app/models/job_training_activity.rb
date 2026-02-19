class JobTrainingActivity < Activity
  include DocumentUploadable

  def document_upload_object_title
    program_name
  end

  def document_upload_months_to_verify
    # TODO: Use the proper months when we allow looping through job training month
    # input pages.
    Array(date.beginning_of_month)
  end

  def document_upload_details_for_month(month)
    # TODO: Use the proper hours for each month when we allow looping through
    # job training hours input pages.
    I18n.t("shared.hours", count: hours) if month.all_month.include?(date)
  end
end

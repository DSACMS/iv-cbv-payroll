# Include this module on an Activity class that can have attached documents.
module DocumentUploadable
  extend ActiveSupport::Concern

  included do
    has_many_attached :document_uploads
  end

  # Required!
  #
  # Implement this method with the identifiable object of the activity
  # (which will be used in the page title).
  def document_upload_object_title
    raise NotImplementedError.new("#{self.class.name} must implement #document_upload_object_title")
  end

  # Override this method to alter the behavior for an activity type if not all
  # months in the reporting window need verification.
  #
  # This is provided to the user as a list at the top of the document upload
  # page, e.g.:
  # * January (<details for January>)
  # * February (<details for February>)
  def document_upload_months_to_verify
    activity_flow.reporting_window_months.times.map do |i|
      activity_flow.reporting_window_range.begin + i.months
    end
  end

  # Override this method to give different contextual details for each
  # month of within the reporting window.
  #
  # These "details" are shown in the <ul> of months at the top of the page,
  # e.g.:
  # * January (<details for January>)
  # * Feburary (<details for Feburary>)
  def document_upload_details_for_month(month)
    nil
  end

  # Override this method to give different suggested document types in
  # the "Suggested documents" accordion.
  def document_upload_suggestion_text
    I18n.t("activities.document_uploads.new.suggestion_text_html")
  end
end

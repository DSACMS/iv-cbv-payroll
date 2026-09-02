require "rack/mime"

class ActivityDocumentsService
  ACTIVITY_ASSOCIATIONS = %i[
    volunteering_activities
    job_training_activities
    education_activities
    employment_activities
  ].freeze

  Document = Struct.new(:attachment, :file_name, :activity)

  def initialize(activity_flow)
    @activity_flow = activity_flow
  end

  def all
    page_numbers = Hash.new(0)

    ACTIVITY_ASSOCIATIONS.flat_map do |association|
      @activity_flow.public_send(association).published.order(:id).flat_map do |activity|
        activity.document_uploads_attachments.includes(:blob).order(:id).map do |attachment|
          activity_type = activity.class.activity_type
          document_name, extension = document_name_and_extension(attachment)
          page_number_key = [ activity_type, document_name ]
          page_number = page_numbers[page_number_key] += 1

          Document.new(
            attachment,
            [ @activity_flow.confirmation_code, activity_type, document_name, page_number ].join("_") + extension,
            activity
          )
        end
      end
    end
  end

  private

  def document_name_and_extension(attachment)
    file_name = attachment.filename.to_s
    original_extension = File.extname(file_name)
    extension = original_extension.downcase
    extension = Rack::Mime::MIME_TYPES.key(attachment.blob.content_type) || ".bin" if extension.blank?

    document_name = File.basename(file_name, original_extension).parameterize(separator: "_")
    document_name = "document" if document_name.blank?
    [ document_name, extension ]
  end
end

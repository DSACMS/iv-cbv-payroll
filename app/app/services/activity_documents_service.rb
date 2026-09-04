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
    taken_file_names = Set.new

    ACTIVITY_ASSOCIATIONS.flat_map do |association|
      @activity_flow.public_send(association).published.order(:id).flat_map do |activity|
        activity.document_uploads_attachments.includes(:blob).order(:id).map do |attachment|
          document_name, extension = document_name_and_extension(attachment)
          prefix = [ @activity_flow.confirmation_code, activity.class.activity_type, document_name ].join("_")

          Document.new(attachment, deduplicated_file_name(prefix, extension, taken_file_names), activity)
        end
      end
    end
  end

  private

  def deduplicated_file_name(prefix, extension, taken_file_names)
    file_name = "#{prefix}#{extension}"
    duplicate_count = 1

    while taken_file_names.include?(file_name)
      duplicate_count += 1
      file_name = "#{prefix}_#{duplicate_count}#{extension}"
    end

    taken_file_names << file_name
    file_name
  end

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

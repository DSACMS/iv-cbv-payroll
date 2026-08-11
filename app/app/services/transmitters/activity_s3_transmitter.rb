require "tmpdir"
require "rack/mime"

class Transmitters::ActivityS3Transmitter
  TRANSMISSION_METHOD = "encrypted_s3"
  ACTIVITY_ASSOCIATIONS = %i[
    volunteering_activities
    job_training_activities
    education_activities
    employment_activities
  ].freeze
  PDF_MARGIN = { top: 10, bottom: 10, left: 10, right: 10 }.freeze

  Document = Struct.new(:attachment, :file_name)

  def initialize(activity_flow, current_agency)
    @activity_flow = activity_flow
    @transmission_config = current_agency.transmission_method_configuration
    @processed_s3_service = S3Service.new("bucket" => ENV.fetch("PROCESSED_BUCKET_NAME"))
    @destination_s3_service = S3Service.new("bucket" => @transmission_config.fetch("bucket"))
  end

  def deliver
    documents = supporting_documents

    Dir.mktmpdir("activity-flow-transmission-") do |directory|
      File.binwrite(File.join(directory, report_file_name), pdf_content)

      documents.each do |document|
        @processed_s3_service.download_file(
          document.attachment.blob.key,
          File.join(directory, document.file_name)
        )
      end

      @destination_s3_service.upload_directory(directory, destination_prefix)
      Rails.logger.info(
        "Activity flow S3 transmission flow_id=#{@activity_flow.id} " \
          "confirmation_code=#{@activity_flow.confirmation_code} " \
          "document_count=#{documents.size}"
      )
    end
  end

  private

  def supporting_documents
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
            [
              @activity_flow.confirmation_code,
              activity_type,
              document_name,
              page_number
            ].join("_") + extension
          )
        end
      end
    end
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

  def report_file_name
    "HR1_Report_#{@activity_flow.completed_at.to_date.iso8601}.pdf"
  end

  def destination_prefix
    File.join(
      @transmission_config.fetch("s3_directory", "outfiles"),
      @activity_flow.confirmation_code,
      ""
    )
  end

  def pdf_content
    assigns = {
      flow: @activity_flow,
      community_service_activities: @activity_flow.volunteering_activities.published.order(date: :desc, created_at: :desc),
      work_programs_activities: @activity_flow.job_training_activities.published.order(created_at: :desc),
      education_activities: @activity_flow.education_activities.published.order(created_at: :desc),
      submission_timestamp: @activity_flow.completed_at,
      total_hours: ActivityFlowProgressCalculator.new(@activity_flow).overall_result.total_hours
    }

    html = I18n.with_locale(:en) do
      Activities::SubmitController.new.render_to_string(
        template: "activities/submit/show",
        formats: [ :pdf ],
        layout: "layouts/pdf",
        assigns: assigns
      )
    end

    WickedPdf.new.pdf_from_string(html, margin: PDF_MARGIN)
  end
end

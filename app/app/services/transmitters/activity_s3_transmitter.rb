require "tmpdir"

class Transmitters::ActivityS3Transmitter
  TRANSMISSION_METHOD = "encrypted_s3"
  include ActivityTransmitter

  def initialize(activity_flow, current_agency)
    super
    @processed_s3_service = ProcessedDownloadService.new
    @destination_s3_service = S3Service.new("bucket" => transmission_configuration.fetch("bucket"))
  end

  def deliver
    documents = supporting_documents
    report = ActivityReportPdfService.new(@activity_flow).generate

    Dir.mktmpdir("activity-flow-transmission-") do |directory|
      File.binwrite(File.join(directory, report.file_name), report.content)

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
    ActivityDocumentsService.new(@activity_flow).all
  end

  def destination_prefix
    File.join(
      transmission_configuration.fetch("s3_directory", "outfiles"),
      @activity_flow.confirmation_code,
      ""
    )
  end
end

require "tmpdir"

class Transmitters::ActivityS3Transmitter
  TRANSMISSION_METHOD = "encrypted_s3"
  PDF_MARGIN = { top: 10, bottom: 10, left: 10, right: 10 }.freeze

  def initialize(activity_flow, current_agency)
    @activity_flow = activity_flow
    @transmission_config = current_agency.transmission_method_configuration
    @processed_s3_service = ProcessedDownloadService.new
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
    ActivityDocumentsService.new(@activity_flow).all
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

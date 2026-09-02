require "rails_helper"

RSpec.describe Transmitters::HttpDocumentTransmitter do
  let(:activity_flow) do
    create(
      :activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      employment_activities_count: 0,
      confirmation_code: "SANDBOX123"
    )
  end
  let(:processed_download_service) { instance_double(ProcessedDownloadService) }
  let(:api_url) { "http://fake-state.api.gov/documents" }
  let(:current_agency) do
    instance_double(
      ClientAgencyConfig::ClientAgency,
      id: "sandbox",
      activity_transmission_method_configuration: { "documents_api_url" => api_url }
    )
  end
  let(:transmitter) { described_class.new(activity_flow, current_agency) }

  before do
    allow(ProcessedDownloadService).to receive(:new).and_return(processed_download_service)
    allow(User).to receive(:api_key_for_agency).with("sandbox").and_return("api-key")
    allow(Rails.logger).to receive(:info)
  end

  it "posts each cleared document with its normalized filename and content type" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    pdf = attach_document(volunteering, "Time Sheet.PDF", "application/pdf")
    image = attach_document(volunteering, "Time Sheet.jpg", "image/jpeg")
    files = { pdf.blob.key => "pdf content", image.blob.key => "image content" }
    allow(processed_download_service).to receive(:download_file) do |key, path|
      File.binwrite(path, files.fetch(key))
    end

    pdf_request = stub_request(:post, api_url).with(
      body: "pdf content",
      headers: {
        "Content-Type" => "application/pdf",
        "Content-Disposition" => 'attachment; filename="SANDBOX123_community_service_time_sheet_1.pdf"',
        "X-IVAAS-Confirmation-Code" => "SANDBOX123"
      }
    )
    image_request = stub_request(:post, api_url).with(
      body: "image content",
      headers: {
        "Content-Type" => "image/jpeg",
        "Content-Disposition" => 'attachment; filename="SANDBOX123_community_service_time_sheet_2.jpg"',
        "X-IVAAS-Confirmation-Code" => "SANDBOX123"
      }
    )

    transmitter.deliver

    expect(pdf_request).to have_been_made.once
    expect(image_request).to have_been_made.once
  end

  it "does not make HTTP requests when the flow has no supporting documents" do
    expect(processed_download_service).not_to receive(:download_file)
    expect(Rails.logger).to receive(:info).with(include("document_count=0"))

    transmitter.deliver
  end

  it "does not transmit later documents when downloading a document fails" do
    activity = create(:volunteering_activity, activity_flow: activity_flow)
    attachment = attach_document(activity, "Timesheet.pdf", "application/pdf")
    allow(processed_download_service).to receive(:download_file).and_raise(StandardError, "missing processed object")

    expect { transmitter.deliver }.to raise_error(StandardError, "missing processed object")
  end

  it "raises a transmitter error when the agency rejects a document" do
    activity = create(:volunteering_activity, activity_flow: activity_flow)
    attachment = attach_document(activity, "Timesheet.pdf", "application/pdf")
    allow(processed_download_service).to receive(:download_file) { |_key, path| File.binwrite(path, "document content") }
    stub_request(:post, api_url).to_return(status: [ 500, "Internal Server Error" ])

    expect { transmitter.deliver }
      .to raise_error(described_class::HttpDocumentTransmitterError, /code=500 message=Internal Server Error/)
  end

  it "raises a silenceable error for configured response codes" do
    activity = create(:volunteering_activity, activity_flow: activity_flow)
    attach_document(activity, "Timesheet.pdf", "application/pdf")
    allow(processed_download_service).to receive(:download_file) { |_key, path| File.binwrite(path, "document content") }
    allow(current_agency).to receive(:activity_transmission_method_configuration)
      .and_return({ "documents_api_url" => api_url, "silently_retry_error_codes" => [ 403 ] })
    stub_request(:post, api_url).to_return(status: [ 403, "Forbidden" ])

    expect { transmitter.deliver }.to raise_error(ApplicationJob::SilencedError, /code=403 message=Forbidden/)
  end

  def attach_document(activity, filename, content_type)
    activity.document_uploads.attach(
      io: StringIO.new("synthetic document"),
      filename: filename,
      content_type: content_type
    )
    activity.document_uploads_attachments.order(:id).last
  end
end

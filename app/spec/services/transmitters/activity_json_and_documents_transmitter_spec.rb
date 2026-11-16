require "rails_helper"

RSpec.describe Transmitters::ActivityJsonAndDocumentsTransmitter do
  let(:json_api_url) { "https://agency.example.gov/ce-activity-report" }
  let(:documents_api_url) { "https://agency.example.gov/documents" }
  let(:json_statuses) { [] }
  let(:document_statuses) { [] }
  let(:requests) { [] }
  let(:activity_flow) do
    create(
      :activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      employment_activities_count: 0,
      completed_at: Time.zone.parse("2026-08-04 12:00:00"),
      confirmation_code: "SANDBOX123"
    )
  end
  let(:current_agency) do
    instance_double(
      ClientAgencyConfig::ClientAgency,
      id: "sandbox",
      activity_transmission_method_configuration: {
        "json_api_url" => json_api_url,
        "documents_api_url" => documents_api_url
      }
    )
  end
  let(:report) do
    ActivityReportPdfService::Report.new(
      content: "%PDF-1.4 report",
      file_name: "HR1_Report_2026-08-04.pdf",
      document_id: "REPORT-#{activity_flow.id}"
    )
  end
  let(:processed_download_service) { instance_double(ProcessedDownloadService) }
  let(:transmitter) { described_class.new(activity_flow, current_agency) }
  let(:json_requests) { requests.select { |request| request[:url] == json_api_url } }
  let(:document_requests) { requests.select { |request| request[:url] == documents_api_url } }
  let(:upload) do
    activity = create(:volunteering_activity, activity_flow: activity_flow)
    activity.document_uploads.attach(
      io: StringIO.new("synthetic document"),
      filename: "Timesheet.pdf",
      content_type: "application/pdf"
    )
    activity.document_uploads_attachments.order(:id).last
  end
  let(:expected_documents) do
    [
      { document_id: "DOC-#{upload.id}", file_name: "SANDBOX123_community_service_timesheet.pdf" },
      { document_id: "REPORT-#{activity_flow.id}", file_name: "HR1_Report_2026-08-04.pdf" }
    ]
  end
  let(:include_upload) { true }
  let(:json_documents) do
    JSON.parse(json_requests.sole.fetch(:body)).fetch("ce_report").fetch("documents")
  end
  let(:pdf_json_document) do
    {
      "document_id" => report.document_id,
      "document_name" => report.file_name,
      "file_type" => "pdf"
    }
  end

  before do
    upload if include_upload
    allow(User).to receive(:api_key_for_agency).with("sandbox").and_return("api-key")
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(ProcessedDownloadService).to receive(:new).and_return(processed_download_service)
    allow(processed_download_service).to receive(:download_file) do |_key, path|
      File.binwrite(path, "synthetic document")
    end
    allow(ActivityReportPdfService).to receive(:new)
      .with(activity_flow)
      .and_return(instance_double(ActivityReportPdfService, generate: report))

    stub_request(:post, json_api_url).to_return do |request|
      requests << recorded_request(json_api_url, request)
      { status: json_statuses.shift || 200 }
    end
    stub_request(:post, documents_api_url).to_return do |request|
      requests << recorded_request(documents_api_url, request)
      { status: document_statuses.shift || 200 }
    end
  end

  context "when every request succeeds" do
    before { transmitter.deliver }

    it "sends the JSON before the uploaded document and report PDF" do
      expect(requests.map { |request| request.slice(:url, :document_id) }).to eq([
        { url: json_api_url, document_id: nil },
        { url: documents_api_url, document_id: "DOC-#{upload.id}" },
        { url: documents_api_url, document_id: "REPORT-#{activity_flow.id}" }
      ])
    end

    it "sends every request with the same confirmation code" do
      expect(requests.map { |request| request[:confirmation_code] }.uniq).to eq([ "SANDBOX123" ])
    end

    it "records that the JSON was delivered" do
      expect(activity_flow.reload.json_transmitted_at).to be_present
    end

    it "lists the report PDF in the JSON" do
      expect(json_documents).to include(pdf_json_document)
    end

    it "uses matching JSON and document request IDs and filenames" do
      expect(json_documents.map { |document| document.values_at("document_id", "document_name") })
        .to eq(document_requests.map { |request| request.values_at(:document_id, :file_name) })
    end
  end

  context "when no supporting documents were uploaded" do
    let(:include_upload) { false }

    before { transmitter.deliver }

    it "lists only the report PDF in the JSON" do
      expect(json_documents).to eq([ pdf_json_document ])
    end

    it "sends the PDF after the JSON" do
      expect(requests.map { |request| request.slice(:url, :document_id) }).to eq([
        { url: json_api_url, document_id: nil },
        { url: documents_api_url, document_id: report.document_id }
      ])
    end
  end

  context "when the JSON request fails" do
    let(:json_statuses) { [ 500 ] }
    let(:delivery_error) do
      transmitter.deliver
      nil
    rescue StandardError => error
      error
    end

    before do
      delivery_error
    end

    it "raises the JSON transmitter error" do
      expect(delivery_error).to be_a(Transmitters::ActivityJsonTransmitter::ActivityJsonTransmitterError)
    end

    it "does not send documents" do
      expect(document_requests).to be_empty
    end

    it "does not record JSON delivery" do
      expect(activity_flow.reload.json_transmitted_at).to be_nil
    end
  end

  context "when the report PDF request fails and the job retries" do
    let(:document_statuses) { [ 200, 500 ] }
    let(:first_attempt_documents) do
      document_requests.first(2).map { |request| request.slice(:document_id, :file_name) }
    end
    let(:retry_documents) do
      document_requests.last(2).map { |request| request.slice(:document_id, :file_name) }
    end
    let(:first_attempt_error) do
      transmitter.deliver
      nil
    rescue StandardError => error
      error
    end

    before do
      first_attempt_error
      described_class.new(activity_flow.reload, current_agency).deliver
    end

    it "fails the first attempt with a document transmitter error" do
      expect(first_attempt_error).to be_a(Transmitters::HttpDocumentTransmitter::HttpDocumentTransmitterError)
    end

    it "does not resend the JSON" do
      expect(json_requests.size).to eq(1)
    end

    it "send every document on the first attempt" do
      expect(first_attempt_documents).to eq(expected_documents)
    end

    it "resends every document with the same IDs and filenames" do
      expect(retry_documents).to eq(expected_documents)
    end

    it "includes the report PDF in the JSON sent before the retry" do
      expect(json_documents).to include(pdf_json_document)
    end
  end

  context "when the JSON was already delivered" do
    before do
      activity_flow.update!(json_transmitted_at: Time.current)
      transmitter.deliver
    end

    it "sends only documents" do
      expect(requests.map { |request| request[:url] }).to all(eq(documents_api_url))
    end
  end

  def recorded_request(url, request)
    {
      url: url,
      body: request.body,
      confirmation_code: request.headers["X-Ivaas-Confirmation-Code"],
      document_id: request.headers["X-Ivaas-Document-Id"],
      file_name: request.headers["Content-Disposition"].to_s[/filename="([^"]+)"/, 1]
    }
  end
end

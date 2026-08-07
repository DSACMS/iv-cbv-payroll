require "rails_helper"

RSpec.describe Transmitters::ActivityS3Transmitter do
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
  let(:processed_bucket_name) { "processed-bucket" }
  let(:destination_bucket_name) { "outbound-bucket" }
  let(:expected_destination_prefix) { "outfiles/SANDBOX123/" }
  let(:report_file_name) { "HR1_Report_2026-08-04.pdf" }
  let(:current_agency) do
    instance_double(
      ClientAgencyConfig::ClientAgency,
      transmission_method_configuration: {
        "bucket" => destination_bucket_name,
        "s3_directory" => "outfiles"
      }
    )
  end
  let(:processed_s3_service) { instance_double(S3Service) }
  let(:destination_s3_service) { instance_double(S3Service) }
  let(:pdf_content) { "%PDF-1.4 report" }
  let(:transmitter) { described_class.new(activity_flow, current_agency) }

  around do |example|
    stub_environment_variable("PROCESSED_BUCKET_NAME", processed_bucket_name, &example)
  end

  before do
    allow(S3Service).to receive(:new)
      .with({ "bucket" => processed_bucket_name })
      .and_return(processed_s3_service)
    allow(S3Service).to receive(:new)
      .with({ "bucket" => destination_bucket_name })
      .and_return(destination_s3_service)
    allow(transmitter).to receive(:pdf_content).and_return(pdf_content)
  end

  it "uses the processed and agency destination buckets by default" do
    expect(S3Service).to have_received(:new)
      .with({ "bucket" => processed_bucket_name })
    expect(S3Service).to have_received(:new)
      .with({ "bucket" => destination_bucket_name })
  end

  it "renders the existing CE report as a PDF" do
    allow(transmitter).to receive(:pdf_content).and_call_original
    expect(destination_s3_service).to receive(:upload_directory) do |directory, _prefix|
      expect(File.binread(File.join(directory, report_file_name))).to start_with("%PDF")
    end

    transmitter.deliver
  end

  it "uploads only the report when the flow has no supporting documents" do
    expect(processed_s3_service).not_to receive(:download_file)
    expect(destination_s3_service).to receive(:upload_directory).ordered do |directory, prefix|
      expect(prefix).to eq(expected_destination_prefix)
      expect(Dir.children(directory)).to contain_exactly(report_file_name)
      expect(File.binread(File.join(directory, report_file_name))).to eq(pdf_content)
    end
    expect(Rails.logger).to receive(:info)
      .with(include("flow_id=#{activity_flow.id}", "document_count=0"))
      .ordered

    transmitter.deliver
  end

  it "downloads published activity documents by blob key and uploads the complete batch" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    first_timesheet = attach_document(volunteering, "Time Sheet.PDF")
    second_timesheet = attach_document(volunteering, "Time Sheet.jpg")

    job_training = create(:job_training_activity, activity_flow: activity_flow)
    enrollment = attach_document(job_training, "Enrollment Letter.jpeg")

    education = create(
      :education_activity,
      activity_flow: activity_flow,
      data_source: :fully_self_attested,
      school_name: "Example College"
    )
    transcript = attach_document(education, "Transcript (Final).pdf")

    employment = create(:employment_activity, activity_flow: activity_flow)
    pay_stub = attach_document(employment, "Pay Stub.png")

    draft = create(:volunteering_activity, :pre_populated_draft, activity_flow: activity_flow)
    attach_document(draft, "Draft Document.pdf")

    downloaded_keys = []
    allow(processed_s3_service).to receive(:download_file) do |key, file_path|
      downloaded_keys << key
      File.binwrite(file_path, "cleared #{key}")
    end

    expected_files = [
      report_file_name,
      "SANDBOX123_community_service_time_sheet_1.pdf",
      "SANDBOX123_community_service_time_sheet_2.jpg",
      "SANDBOX123_work_programs_enrollment_letter_1.jpeg",
      "SANDBOX123_education_transcript_final_1.pdf",
      "SANDBOX123_employment_pay_stub_1.png"
    ]
    expect(destination_s3_service).to receive(:upload_directory) do |directory, _prefix|
      expect(Dir.children(directory)).to match_array(expected_files)
    end

    transmitter.deliver

    expect(downloaded_keys).to eq([
      first_timesheet.blob.key,
      second_timesheet.blob.key,
      enrollment.blob.key,
      transcript.blob.key,
      pay_stub.blob.key
    ])
  end

  it "does not begin the destination upload when a processed object is missing" do
    activity = create(:volunteering_activity, activity_flow: activity_flow)
    attach_document(activity, "Timesheet.pdf")
    allow(processed_s3_service).to receive(:download_file).and_raise(StandardError, "missing processed object")

    expect(destination_s3_service).not_to receive(:upload_directory)

    expect { transmitter.deliver }.to raise_error(StandardError, "missing processed object")
  end

  it "derives an extension for extensionless filenames without blocking the batch" do
    activity = create(:volunteering_activity, activity_flow: activity_flow)
    pdf = attach_document(activity, "Scanned Timesheet")
    pdf.blob.update!(content_type: "application/pdf")
    unknown = attach_document(activity, "Other Document")
    unknown.blob.update!(content_type: "application/x-unknown")

    allow(processed_s3_service).to receive(:download_file) do |_key, file_path|
      File.binwrite(file_path, "cleared document")
    end
    expect(destination_s3_service).to receive(:upload_directory) do |directory, _prefix|
      expect(Dir.children(directory)).to contain_exactly(
        report_file_name,
        "SANDBOX123_community_service_scanned_timesheet_1.pdf",
        "SANDBOX123_community_service_other_document_1.bin"
      )
    end

    transmitter.deliver
  end

  it "raises when the destination batch upload fails" do
    allow(destination_s3_service).to receive(:upload_directory).and_raise(StandardError, "upload failed")

    expect { transmitter.deliver }.to raise_error(StandardError, "upload failed")
  end

  def attach_document(activity, filename)
    activity.document_uploads.attach(
      io: StringIO.new("synthetic document"),
      filename: filename,
      content_type: Marcel::MimeType.for(name: filename)
    )
    activity.document_uploads_attachments.order(:id).last
  end
end

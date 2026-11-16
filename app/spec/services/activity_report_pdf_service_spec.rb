require "rails_helper"

RSpec.describe ActivityReportPdfService do
  let(:activity_flow) do
    create(
      :activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      employment_activities_count: 0,
      completed_at: Time.zone.parse("2026-08-04 23:30:00"),
      confirmation_code: "SANDBOX123"
    )
  end
  let(:first_report) { described_class.new(activity_flow).generate }
  let(:retry_report) { described_class.new(activity_flow.reload).generate }

  before do
    allow(PdfRenderer).to receive(:render).and_return("%PDF-1.4 report")
  end

  it "uses the flow completion date in the filename" do
    expect(first_report.file_name).to eq("HR1_Report_2026-08-04.pdf")
  end

  it "uses the flow ID as the document ID" do
    expect(first_report.document_id).to eq("REPORT-#{activity_flow.id}")
  end

  it "keeps the document metadata stable across retries" do
    expect(retry_report.to_h.slice(:document_id, :file_name))
      .to eq(first_report.to_h.slice(:document_id, :file_name))
  end

  it "renders with the shared PDF margins" do
    first_report

    expect(PdfRenderer).to have_received(:render)
      .with(kind_of(String), margin: described_class::PDF_MARGIN)
  end
end

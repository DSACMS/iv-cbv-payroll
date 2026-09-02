require "rails_helper"

RSpec.describe ActivityDocumentsService do
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

  it "names each document after the flow, activity type, document name, and page number" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    attach_document(volunteering, "Time Sheet.PDF")
    attach_document(volunteering, "Time Sheet.jpg")

    expect(described_class.new(activity_flow).all.map(&:file_name)).to eq([
      "SANDBOX123_community_service_time_sheet_1.pdf",
      "SANDBOX123_community_service_time_sheet_2.jpg"
    ])
  end

  it "records the activity each document belongs to" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    attach_document(volunteering, "Time Sheet.pdf")
    job_training = create(:job_training_activity, activity_flow: activity_flow)
    attach_document(job_training, "Enrollment Letter.pdf")

    expect(described_class.new(activity_flow).all.map(&:activity)).to eq([ volunteering, job_training ])
  end

  it "excludes documents attached to draft activities" do
    draft = create(:volunteering_activity, :pre_populated_draft, activity_flow: activity_flow)
    attach_document(draft, "Draft Document.pdf")

    expect(described_class.new(activity_flow).all).to be_empty
  end

  def attach_document(activity, filename)
    activity.document_uploads.attach(
      io: StringIO.new("synthetic document"),
      filename: filename,
      content_type: Marcel::MimeType.for(name: filename)
    )
  end
end

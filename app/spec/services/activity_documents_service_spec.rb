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

  it "names each document after the flow, activity type, and document name" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    attach_document(volunteering, "Time Sheet.PDF")

    expect(described_class.new(activity_flow).all.map(&:file_name))
      .to eq([ "SANDBOX123_community_service_time_sheet.pdf" ])
  end

  it "does not number documents whose names differ only by extension" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    attach_document(volunteering, "Time Sheet.PDF")
    attach_document(volunteering, "Time Sheet.jpg")

    expect(described_class.new(activity_flow).all.map(&:file_name)).to eq([
      "SANDBOX123_community_service_time_sheet.pdf",
      "SANDBOX123_community_service_time_sheet.jpg"
    ])
  end

  it "numbers only the documents that would otherwise collide" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    3.times { attach_document(volunteering, "Time Sheet.pdf") }

    expect(described_class.new(activity_flow).all.map(&:file_name)).to eq([
      "SANDBOX123_community_service_time_sheet.pdf",
      "SANDBOX123_community_service_time_sheet_2.pdf",
      "SANDBOX123_community_service_time_sheet_3.pdf"
    ])
  end

  it "numbers collisions across separate activities of the same type" do
    first = create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Food Bank")
    attach_document(first, "Timesheet.pdf")
    second = create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Animal Shelter")
    attach_document(second, "Timesheet.pdf")

    expect(described_class.new(activity_flow).all.map(&:file_name)).to eq([
      "SANDBOX123_community_service_timesheet.pdf",
      "SANDBOX123_community_service_timesheet_2.pdf"
    ])
  end

  it "does not number the same document name used by different activity types" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    attach_document(volunteering, "Timesheet.pdf")
    job_training = create(:job_training_activity, activity_flow: activity_flow)
    attach_document(job_training, "Timesheet.pdf")

    expect(described_class.new(activity_flow).all.map(&:file_name)).to eq([
      "SANDBOX123_community_service_timesheet.pdf",
      "SANDBOX123_work_programs_timesheet.pdf"
    ])
  end

  it "does not collide when an uploaded name already ends in a duplicate suffix" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    attach_document(volunteering, "Timesheet.pdf")
    attach_document(volunteering, "Timesheet 2.pdf")
    attach_document(volunteering, "Timesheet.pdf")

    file_names = described_class.new(activity_flow).all.map(&:file_name)

    expect(file_names).to eq([
      "SANDBOX123_community_service_timesheet.pdf",
      "SANDBOX123_community_service_timesheet_2.pdf",
      "SANDBOX123_community_service_timesheet_3.pdf"
    ])
    expect(file_names.uniq.size).to eq(3)
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

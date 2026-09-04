require "rails_helper"

RSpec.describe ActivityReportSerializer do
  let(:cbv_applicant) do
    create(:cbv_applicant, client_agency_id: "sandbox", first_name: "Jane", middle_name: "A", last_name: "Doe",
      case_number: "CASE-2026-00987", date_of_birth: Date.new(1990, 4, 15))
  end
  let(:activity_flow) do
    create(
      :activity_flow,
      cbv_applicant: cbv_applicant,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      employment_activities_count: 0,
      with_identity: false,
      created_at: Time.zone.parse("2026-08-11 12:00:00"),
      completed_at: Time.zone.parse("2026-08-11 14:00:00"),
      confirmation_code: "SANDBOX123"
    )
  end
  let(:current_agency) { Rails.application.config.client_agencies["sandbox"] }
  let(:report) { described_class.new(activity_flow, current_agency).as_json }
  let(:first_month) { activity_flow.reporting_months.first }
  let(:second_month) { activity_flow.reporting_months.second }

  it "stamps the schema version and flow identifiers at the root" do
    expect(report).to include(
      "schema_version" => "1.0.0",
      "confirmation_code" => "SANDBOX123",
      "completed_at" => "2026-08-11T14:00:00Z"
    )
  end

  it "builds the agency object from the agency's configured applicant attributes" do
    expect(report["agency"]).to eq(
      "first_name" => "Jane",
      "middle_name" => "A",
      "last_name" => "Doe",
      "case_number" => "CASE-2026-00987",
      "date_of_birth" => "1990-04-15",
      "extended_attributes" => {}
    )
  end

  it "reports the individual's name and the review period covered by the flow" do
    expect(report["ce_report"]["individual"]).to eq(
      "name" => { "first" => "Jane", "middle" => "A", "last" => "Doe" },
      "extended_attributes" => {}
    )
    expect(report["ce_report"]["review_period"]).to eq(
      "start_month" => "2026-06",
      "end_month" => "2026-07"
    )
  end

  it "groups activities by type at the top level and by month within each type" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 40)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: second_month, hours: 12.5)

    job_training = create(:job_training_activity, activity_flow: activity_flow)
    create(:job_training_activity_month, job_training_activity: job_training, month: second_month, hours: 8)

    expect(report["ce_report"]["activities"].keys).to eq(%w[community_service work_program])
    expect(report["ce_report"]["activities"]["community_service"].keys).to eq(%w[2026-06 2026-07])
    expect(report["ce_report"]["activities"]["work_program"].keys).to eq(%w[2026-07])
  end

  it "repeats the month inside each entry so entries stand alone" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: second_month, hours: 12.5)

    entries = report["ce_report"]["activities"]["community_service"]

    expect(entries["2026-07"].sole["month"]).to eq("2026-07")
  end

  it "orders months chronologically regardless of the order the months were created" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: second_month, hours: 12.5)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 40)

    expect(report["ce_report"]["activities"]["community_service"].keys).to eq(%w[2026-06 2026-07])
  end

  it "emits the community service fields the agency spec requires" do
    volunteering = create(
      :volunteering_activity,
      activity_flow: activity_flow,
      organization_name: "Local Food Bank",
      street_address: "1 Main St",
      street_address_line_2: nil,
      city: "New Orleans",
      state: "LA",
      zip_code: "70112",
      coordinator_name: "Jane Smith",
      coordinator_email: "jane@example.org",
      coordinator_phone_number: "5045551234",
      additional_comments: "Weekly shifts"
    )
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 40)

    expect(report["ce_report"]["activities"]["community_service"]["2026-06"]).to eq([ {
      "type" => "community_service",
      "organization_name" => "Local Food Bank",
      "street_address" => "1 Main St",
      "street_address_line_2" => nil,
      "city" => "New Orleans",
      "state" => "LA",
      "zip_code" => "70112",
      "coordinator_name" => "Jane Smith",
      "coordinator_email" => "jane@example.org",
      "coordinator_phone_number" => "5045551234",
      "additional_comments" => "Weekly shifts",
      "month" => "2026-06",
      "hours" => 40.0,
      "data_source" => "self_attested",
      "document_ids" => [],
      "extended_attributes" => {}
    } ])
  end

  it "emits work program entries with the singular type name the agency spec uses" do
    job_training = create(
      :job_training_activity,
      activity_flow: activity_flow,
      organization_name: "Goodwill",
      program_name: "Resume Workshop",
      contact_name: "Casey Doe",
      contact_email: "casey@example.org",
      contact_phone_number: "5045555678"
    )
    create(:job_training_activity_month, job_training_activity: job_training, month: first_month, hours: 8)

    entry = report["ce_report"]["activities"]["work_program"]["2026-06"].sole

    expect(entry).to include(
      "type" => "work_program",
      "organization_name" => "Goodwill",
      "program_name" => "Resume Workshop",
      "contact_name" => "Casey Doe",
      "contact_email" => "casey@example.org",
      "contact_phone_number" => "5045555678",
      "hours" => 8.0
    )
  end

  it "reports optional fields the applicant left blank as null rather than an empty string" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow,
      street_address_line_2: "", coordinator_phone_number: "", additional_comments: "")
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 40)

    expect(report["ce_report"]["activities"]["community_service"]["2026-06"].sole).to include(
      "street_address_line_2" => nil,
      "coordinator_phone_number" => nil,
      "additional_comments" => nil
    )
  end

  it "preserves fractional hours exactly as the applicant entered them" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 12.75)

    expect(report["ce_report"]["activities"]["community_service"]["2026-06"].sole["hours"]).to eq(12.75)
  end

  it "includes months the applicant reported as zero hours" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 0)

    expect(report["ce_report"]["activities"]["community_service"]["2026-06"].sole["hours"]).to eq(0.0)
  end

  it "omits months in the review period that have no reported activity" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: second_month, hours: 40)

    expect(report["ce_report"]["activities"]["community_service"].keys).to eq(%w[2026-07])
  end

  it "emits an empty object for an in-scope type with no activities" do
    expect(report["ce_report"]["activities"]).to eq("community_service" => {}, "work_program" => {})
  end

  it "excludes draft activities" do
    draft = create(:volunteering_activity, :pre_populated_draft, activity_flow: activity_flow)
    create(:volunteering_activity_month, volunteering_activity: draft, month: first_month, hours: 40)

    expect(report["ce_report"]["activities"]["community_service"]).to eq({})
  end

  it "reports self-attested as the data source, the only value the agency spec allows here" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 40)

    expect(report["ce_report"]["activities"]["community_service"]["2026-06"].sole["data_source"]).to eq("self_attested")
  end

  it "reports self-attested even for a state-prefilled activity" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow, data_source: :validated)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 40)

    expect(report["ce_report"]["activities"]["community_service"]["2026-06"].sole).to include(
      "data_source" => "self_attested",
      "extended_attributes" => {}
    )
  end

  it "collects multiple activities of the same type into one month bucket" do
    first = create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Local Food Bank")
    create(:volunteering_activity_month, volunteering_activity: first, month: first_month, hours: 40)
    second = create(:volunteering_activity, activity_flow: activity_flow, organization_name: "Animal Shelter")
    create(:volunteering_activity_month, volunteering_activity: second, month: first_month, hours: 10)

    expect(report["ce_report"]["activities"]["community_service"]["2026-06"].map { |entry| entry["organization_name"] })
      .to eq([ "Local Food Bank", "Animal Shelter" ])
  end

  it "omits out-of-scope activity types entirely" do
    create(:education_activity, activity_flow: activity_flow)
    create(:employment_activity, activity_flow: activity_flow)

    expect(report["ce_report"]["activities"].keys).to eq(%w[community_service work_program])
    expect(report["ce_report"]).not_to have_key("income_summary")
  end

  describe "documents" do
    it "lists supporting documents and cross-references them from each activity entry" do
      volunteering = create(:volunteering_activity, activity_flow: activity_flow)
      create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 40)
      attach_document(volunteering, "Time Sheet.PDF")

      job_training = create(:job_training_activity, activity_flow: activity_flow)
      create(:job_training_activity_month, job_training_activity: job_training, month: first_month, hours: 8)
      attach_document(job_training, "WIOA Participation Letter.pdf")

      expect(report["ce_report"]["documents"]).to eq([
        {
          "document_id" => "DOC-001",
          "document_name" => "SANDBOX123_community_service_time_sheet.pdf",
          "file_type" => "pdf"
        },
        {
          "document_id" => "DOC-002",
          "document_name" => "SANDBOX123_work_programs_wioa_participation_letter.pdf",
          "file_type" => "pdf"
        }
      ])
      expect(report["ce_report"]["activities"]["community_service"]["2026-06"].sole["document_ids"]).to eq([ "DOC-001" ])
      expect(report["ce_report"]["activities"]["work_program"]["2026-06"].sole["document_ids"]).to eq([ "DOC-002" ])
    end

    it "excludes documents belonging to out-of-scope activity types" do
      education = create(:education_activity, activity_flow: activity_flow)
      attach_document(education, "Transcript.pdf")

      expect(report["ce_report"]["documents"]).to eq([])
    end
  end

  def attach_document(activity, filename)
    activity.document_uploads.attach(
      io: StringIO.new("synthetic document"),
      filename: filename,
      content_type: Marcel::MimeType.for(name: filename)
    )
  end
end

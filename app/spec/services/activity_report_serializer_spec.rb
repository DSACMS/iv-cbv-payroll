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

  it "builds the agency partner metadata from configured applicant attributes" do
    expect(report["agency_partner_metadata"]).to eq(
      "first_name" => "Jane",
      "middle_name" => "A",
      "last_name" => "Doe",
      "case_number" => "CASE-2026-00987",
      "date_of_birth" => "1990-04-15"
    )
  end

  it "reports the review period covered by the flow" do
    expect(report["ce_report"]["review_period"]).to eq(
      "start_month" => "2026-06",
      "end_month" => "2026-07"
    )
  end

  it "reports blank applicant names as null in agency partner metadata" do
    cbv_applicant.update!(middle_name: "", last_name: "")

    expect(report["agency_partner_metadata"]).to include("middle_name" => nil, "last_name" => nil)
  end

  it "groups activities by type at the top level and by month within each type" do
    volunteering = create(:volunteering_activity, activity_flow: activity_flow)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 40)
    create(:volunteering_activity_month, volunteering_activity: volunteering, month: second_month, hours: 12.5)

    job_training = create(:job_training_activity, activity_flow: activity_flow)
    create(:job_training_activity_month, job_training_activity: job_training, month: second_month, hours: 8)

    expect(report["ce_report"]["activities"].keys).to eq(%w[community_service work_program employment education])
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
      "document_ids" => []
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
    expect(report["ce_report"]["activities"]).to eq("community_service" => {}, "work_program" => {}, "employment" => {}, "education" => {})
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
      "data_source" => "self_attested"
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

  it "reports the supported activity types when employment is present" do
    create(:employment_activity, activity_flow: activity_flow)

    expect(report["ce_report"]["activities"].keys).to eq(%w[community_service work_program employment education])
    expect(report["ce_report"]).not_to have_key("income_summary")
  end

  describe "education" do
    let(:education_entries) { JSON.parse(report.to_json).dig("ce_report", "activities", "education") }

    it "reports monthly self-attested credit hours with school and contact information" do
      education = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "City Community College",
        street_address: "2 Main St",
        street_address_line_2: "",
        city: "New Orleans",
        state: "LA",
        zip_code: "70112",
        contact_name: "Casey Doe",
        contact_title: "Registrar",
        contact_email: "casey@example.org",
        contact_phone_number: "5045555678",
        additional_comments: "Evening classes"
      )
      create(:education_activity_month, education_activity: education, month: second_month, hours: 0)
      create(:education_activity_month, education_activity: education, month: first_month, hours: 3.5)

      expect(education_entries.keys).to eq(%w[2026-06 2026-07])
      expect(education_entries["2026-06"].sole).to eq(
        "type" => "education",
        "month" => "2026-06",
        "school_name" => "City Community College",
        "street_address" => "2 Main St",
        "street_address_line_2" => nil,
        "city" => "New Orleans",
        "state" => "LA",
        "zip_code" => "70112",
        "contact_name" => "Casey Doe",
        "contact_title" => "Registrar",
        "contact_email" => "casey@example.org",
        "contact_phone_number" => "5045555678",
        "additional_comments" => "Evening classes",
        "hours" => 3.5,
        "data_source" => "self_attested",
        "document_ids" => []
      )
      expect(education_entries["2026-07"].sole["hours"]).to eq(0.0)
    end

    it "reports an omitted school official title as null" do
      education = create(:education_activity, activity_flow: activity_flow,
        data_source: :fully_self_attested, school_name: "City Community College")
      create(:education_activity_month, education_activity: education, month: first_month, hours: 3.5)

      expect(education_entries["2026-06"].sole).to include("contact_title" => nil)
    end

    it "reports verified NSC terms in each overlapping reporting month" do
      education = create(
        :education_activity,
        activity_flow: activity_flow,
        status: :succeeded,
        additional_comments: ""
      )
      create(
        :nsc_enrollment_term,
        education_activity: education,
        school_name: "State University",
        enrollment_status: :three_quarter_time,
        term_begin: Date.new(2026, 5, 15),
        term_end: Date.new(2026, 7, 15)
      )

      expect(education_entries.keys).to eq(%w[2026-06 2026-07])
      expect(education_entries["2026-06"].sole).to eq(
        "type" => "education",
        "month" => "2026-06",
        "school_name" => "State University",
        "enrollment_status" => "three_quarter_time",
        "credit_hours" => nil,
        "term" => {
          "start_month" => "2026-05",
          "end_month" => "2026-07"
        },
        "data_source" => "verified",
        "additional_comments" => nil,
        "document_ids" => []
      )
      expect(education_entries["2026-07"].sole["month"]).to eq("2026-07")
    end

    it "collects multiple education activities into one month bucket" do
      first = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "City Community College"
      )
      create(:education_activity_month, education_activity: first, month: first_month, hours: 3.5)
      second = create(:education_activity, activity_flow: activity_flow, status: :succeeded)
      create(
        :nsc_enrollment_term,
        education_activity: second,
        school_name: "State University",
        term_begin: first_month,
        term_end: first_month.end_of_month
      )

      expect(education_entries["2026-06"]).to contain_exactly(
        hash_including(
          "school_name" => "City Community College",
          "hours" => 3.5,
          "data_source" => "self_attested"
        ),
        hash_including(
          "school_name" => "State University",
          "data_source" => "verified"
        )
      )
    end

    it "reports partially self-attested terms with their own school names and credit hours" do
      education = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded
      )
      document = attach_document(education, "Transcript.pdf")
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education,
        school_name: "North College",
        credit_hours: 3.25,
        term_begin: first_month,
        term_end: first_month.end_of_month
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education,
        school_name: "South College",
        credit_hours: 4,
        term_begin: first_month,
        term_end: second_month.end_of_month
      )

      expect(education_entries["2026-06"]).to contain_exactly(
        hash_including(
          "school_name" => "North College",
          "hours" => 3.25,
          "data_source" => "verified_enrollment_only",
          "enrollment_status" => "less_than_half_time",
          "credit_hours" => 3.25,
          "term" => {
            "start_month" => "2026-06",
            "end_month" => "2026-06"
          }
        ),
        hash_including(
          "school_name" => "South College",
          "hours" => 4.0,
          "data_source" => "verified_enrollment_only"
        )
      )
      expect(education_entries["2026-07"].sole).to include(
        "school_name" => "South College",
        "hours" => 4.0,
        "data_source" => "verified_enrollment_only",
        "contact_name" => nil,
        "street_address" => nil
      )
      expect(education_entries.values.flatten).to all(include("document_ids" => [ "DOC-#{document.id}" ]))
    end

    it "preserves enrollment with unknown credit hours in a partially self-attested activity" do
      education = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :partially_self_attested,
        status: :succeeded
      )
      create(
        :nsc_enrollment_term,
        education_activity: education,
        enrollment_status: :half_time,
        term_begin: second_month,
        term_end: second_month.end_of_month
      )

      expect(education_entries.keys).to eq(%w[2026-07])
      expect(education_entries["2026-07"].sole).to include(
        "data_source" => "verified_enrollment_only",
        "enrollment_status" => "half_time",
        "hours" => nil,
        "credit_hours" => nil
      )
    end

    it "includes the qualifying spring term for summer carryover and preserves its original dates" do
      education = create(:education_activity, activity_flow: activity_flow, status: :succeeded)
      create(
        :nsc_enrollment_term,
        education_activity: education,
        school_name: "Spring College",
        term_begin: Date.new(2026, 3, 1),
        term_end: Date.new(2026, 6, 15)
      )
      create(
        :nsc_enrollment_term,
        :less_than_half_time,
        education_activity: education,
        school_name: "Summer College",
        term_begin: second_month,
        term_end: Date.new(2026, 8, 15)
      )

      expect(education_entries["2026-07"]).to contain_exactly(
        hash_including(
          "school_name" => "Spring College",
          "enrollment_status" => "half_time",
          "term" => {
            "start_month" => "2026-03",
            "end_month" => "2026-06"
          }
        ),
        hash_including(
          "school_name" => "Summer College",
          "enrollment_status" => "less_than_half_time"
        )
      )
      expect(education_entries["2026-06"].size).to eq(1)
    end

    it "includes summer carryover when no summer term exists" do
      education = create(:education_activity, activity_flow: activity_flow, status: :succeeded)
      create(
        :nsc_enrollment_term,
        education_activity: education,
        term_begin: Date.new(2026, 3, 1),
        term_end: Date.new(2026, 6, 15)
      )

      expect(education_entries["2026-07"].sole).to include(
        "enrollment_status" => "half_time",
        "term" => {
          "start_month" => "2026-03",
          "end_month" => "2026-06"
        }
      )
    end

    it "omits education drafts and terms outside the reporting window" do
      draft = create(:education_activity, activity_flow: activity_flow, draft: true)
      create(:nsc_enrollment_term, education_activity: draft)
      education = create(:education_activity, activity_flow: activity_flow, status: :succeeded)
      create(
        :nsc_enrollment_term,
        education_activity: education,
        term_begin: Date.new(2026, 9, 1),
        term_end: Date.new(2026, 12, 31)
      )

      expect(education_entries).to eq({})
    end
  end

  describe "employment" do
    let(:employment_months) { report.dig("ce_report", "activities", "employment") }

    it "includes monthly self-attested hours, dollar amounts, comments, and documents" do
      employment = create(:employment_activity, activity_flow: activity_flow, additional_comments: "Seasonal work")
      create(:employment_activity_month, employment_activity: employment, month: second_month, hours: 12.75, gross_income: 123.45)
      create(:employment_activity_month, employment_activity: employment, month: first_month, hours: 0, gross_income: 0)
      document = attach_document(employment, "Paystub.pdf")

      expect(employment_months.keys).to eq(%w[2026-06 2026-07])
      expect(employment_months["2026-07"].sole).to include(
        "type" => "employment", "month" => "2026-07", "data_source" => "self_attested",
        "employer_name" => "Gainesville Wrecking", "is_self_employed" => false,
        "employer_address" => "942 W Harlan Ave, Gainesville, FL 32611", "employment_type" => "w2",
        "hours" => 12.75, "gross_income" => 123.45, "additional_comments" => "Seasonal work",
        "document_ids" => [ "DOC-#{document.id}" ]
      )
      expect(employment_months["2026-06"].sole).to include("hours" => 0.0, "gross_income" => 0.0)
      expect(report.dig("ce_report", "documents").sole["document_id"]).to eq("DOC-#{document.id}")
    end

    it "identifies self-employed and unpaid work and preserves cleared contact fields as null" do
      self_employed = create(:employment_activity, activity_flow: activity_flow, is_self_employed: true)
      unpaid = create(:employment_activity, activity_flow: activity_flow, compensation_type: :unpaid_or_in_kind)
      [ self_employed, unpaid ].each do |employment|
        create(:employment_activity_month, employment_activity: employment, month: first_month, gross_income: 0)
      end

      expect(employment_months["2026-06"].first).to include(
        "employment_type" => "self_employed", "is_self_employed" => true,
        "contact_name" => nil, "contact_email" => nil, "contact_phone_number" => nil
      )
      expect(employment_months["2026-06"].last).to include("employment_type" => "unpaid", "gross_income" => 0.0)
    end

    it "excludes drafts and does not fetch unsuccessful or unpublished payroll connections" do
      draft = create(:employment_activity, :pre_populated_draft, activity_flow: activity_flow)
      create(:employment_activity_month, employment_activity: draft, month: first_month)
      create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow, draft: true)
      create(:payroll_account, flow: activity_flow, synchronization_status: :failed)
      create(:payroll_account, flow: activity_flow, synchronization_status: :in_progress)

      expect_any_instance_of(AggregatorReportFetcher).not_to receive(:report_for_payroll_account)
      expect(employment_months).to eq({})
    end

    context "with a linked payroll account" do
      let!(:account) { create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow, aggregator_account_id: "account1") }
      let(:payroll_report) { build(:pinwheel_report, :hydrated, payroll_accounts: [ account ], has_fetched: true) }
      let(:fetcher) { instance_double(AggregatorReportFetcher) }

      before do
        allow(AggregatorReportFetcher).to receive(:new).with(activity_flow).and_return(fetcher)
        allow(fetcher).to receive(:report_for_payroll_account).with(account).and_return(payroll_report)
        payroll_report.paystubs.first.pay_date = "2026-07-01"
        payroll_report.paystubs.first.pay_period_start = "2026-06-15"
        payroll_report.paystubs.first.pay_period_end = "2026-06-30"
      end

      it "groups by paycheck date and keeps the income report fields and cent amounts" do
        payroll_report.paystubs.first.earnings = [ Aggregators::ResponseObjects::Earning.new(category: "base", amount: 12345) ]
        payroll_report.paystubs.first.deductions = [ { category: "Tax", tax: "pre_tax", amount: 2345 } ]
        income_employment = payroll_report.income_report_employments.sole.as_json

        expect(employment_months.keys).to eq([ "2026-07" ])
        entry = employment_months["2026-07"].sole
        expect(entry.except("type", "month", "data_source", "document_ids", "paystubs"))
          .to eq(income_employment.except("paystubs"))
        expect(entry).to include("data_source" => "validated", "document_ids" => [], "month" => "2026-07")
        expect(entry["paystubs"].sole).to include(
          "pay_date" => "2026-07-01", "pay_period_start" => "2026-06-15", "pay_gross" => 12345,
          "hours_paid" => 12.0, "deductions" => [ { "category" => "Tax", "tax" => "pre_tax", "amount" => 2345 } ],
          "gross_pay_list" => [ { "type" => "base", "amount" => 12345 } ]
        )
        expect(employment_months).not_to have_key("has_other_jobs")
        expect(employment_months).not_to have_key("income_summary")
      end

      it "includes both reporting boundaries, omits undated and out-of-range checks, and sorts months" do
        payroll_report.paystubs = [ "2026-08-01", "2026-07-31", nil, "2026-05-31", "2026-06-01" ].map do |date|
          payroll_report.paystubs.first.dup.tap { |paystub| paystub.pay_date = date }
        end

        expect(employment_months.keys).to eq(%w[2026-06 2026-07])
        expect(employment_months.values.flatten.flat_map { |entry| entry["paystubs"].map { |paystub| paystub["pay_date"] } })
          .to eq(%w[2026-06-01 2026-07-31])
      end

      it "groups multiple payments for one employer into a single monthly entry" do
        payroll_report.paystubs << payroll_report.paystubs.first.dup.tap { |paystub| paystub.pay_date = "2026-07-15" }

        expect(employment_months["2026-07"].sole["paystubs"].size).to eq(2)
      end

      it "combines payroll and self-attested employers in the same month" do
        employment = create(:employment_activity, activity_flow: activity_flow)
        create(:employment_activity_month, employment_activity: employment, month: second_month)

        expect(employment_months["2026-07"].map { |entry| entry["employer_name"] })
          .to eq([ "Gainesville Wrecking", "Cool Company" ])
      end

      it "keeps employers from both providers in the same month without mixing their paychecks" do
        other_account = create(:payroll_account, :argyle_fully_synced, flow: activity_flow, aggregator_account_id: "argyle_report1")
        other_report = build(:argyle_report, payroll_accounts: [ other_account ], has_fetched: true)
        other_report.paystubs.first.pay_date = "2026-07-02"
        allow(fetcher).to receive(:report_for_payroll_account).with(other_account).and_return(other_report)

        entries = employment_months["2026-07"]
        expect(entries.map { |entry| entry["employer_name"] }).to eq([ "Cool Company", "Argyle Test Corp." ])
        expect(entries.map { |entry| entry["paystubs"].sole["pay_date"] }).to eq(%w[2026-07-01 2026-07-02])
      end

      it "omits payroll employers with no payments in the reporting period" do
        payroll_report.paystubs.clear
        expect(employment_months).to eq({})
      end

      it "preserves nullable payroll fields and the income report's missing gross pay fallback" do
        payroll_report.paystubs.first.gross_pay_amount = nil
        payroll_report.paystubs.first.net_pay_amount = nil
        payroll_report.paystubs.first.hours = nil
        payroll_report.incomes.clear
        payroll_report.identities.clear

        entry = employment_months["2026-07"].sole
        expect(entry).to include("applicant_full_name" => nil, "compensation_amount" => nil)
        expect(entry["paystubs"].sole).to include("pay_gross" => 0, "pay_net" => nil, "hours_paid" => nil)
      end

      it "fails serialization when payroll fetching fails so transmission can retry" do
        payroll_report.has_fetched = false

        expect { report }.to raise_error(ActivityReportSerializer::PayrollReportError)
      end
    end
  end

  describe "documents" do
    it "lists supporting documents and cross-references them from each activity entry" do
      volunteering = create(:volunteering_activity, activity_flow: activity_flow)
      create(:volunteering_activity_month, volunteering_activity: volunteering, month: first_month, hours: 40)
      volunteering_document = attach_document(volunteering, "Time Sheet.PDF")

      job_training = create(:job_training_activity, activity_flow: activity_flow)
      create(:job_training_activity_month, job_training_activity: job_training, month: first_month, hours: 8)
      job_training_document = attach_document(job_training, "WIOA Participation Letter.pdf")

      expect(report["ce_report"]["documents"]).to eq([
        {
          "document_id" => "DOC-#{volunteering_document.id}",
          "document_name" => "SANDBOX123_community_service_time_sheet.pdf",
          "file_type" => "pdf"
        },
        {
          "document_id" => "DOC-#{job_training_document.id}",
          "document_name" => "SANDBOX123_work_programs_wioa_participation_letter.pdf",
          "file_type" => "pdf"
        }
      ])
      expect(report["ce_report"]["activities"]["community_service"]["2026-06"].sole["document_ids"])
        .to eq([ "DOC-#{volunteering_document.id}" ])
      expect(report["ce_report"]["activities"]["work_program"]["2026-06"].sole["document_ids"])
        .to eq([ "DOC-#{job_training_document.id}" ])
    end

    it "lists education documents and references them from each reported month" do
      education = create(
        :education_activity,
        activity_flow: activity_flow,
        data_source: :fully_self_attested,
        school_name: "City Community College"
      )
      activity_flow.reporting_months.each do |month|
        create(:education_activity_month, education_activity: education, month: month, hours: 3)
      end
      document = attach_document(education, "Transcript.pdf")

      expect(report["ce_report"]["documents"]).to include(
        "document_id" => "DOC-#{document.id}",
        "document_name" => "SANDBOX123_education_transcript.pdf",
        "file_type" => "pdf"
      )
      expect(report["ce_report"]["activities"]["education"].keys).to eq(%w[2026-06 2026-07])
      report["ce_report"]["activities"]["education"].each_value do |entries|
        expect(entries.sole["document_ids"]).to eq([ "DOC-#{document.id}" ])
      end
    end

    it "lists verified NSC education documents and references them from each reported month" do
      education = create(:education_activity, activity_flow: activity_flow, status: :succeeded)
      create(
        :nsc_enrollment_term,
        education_activity: education,
        term_begin: first_month,
        term_end: second_month.end_of_month
      )
      document = attach_document(education, "Enrollment Letter.pdf")

      expect(report["ce_report"]["documents"]).to include(
        "document_id" => "DOC-#{document.id}",
        "document_name" => "SANDBOX123_education_enrollment_letter.pdf",
        "file_type" => "pdf"
      )
      expect(report["ce_report"]["activities"]["education"].keys).to eq(%w[2026-06 2026-07])
      report["ce_report"]["activities"]["education"].each_value do |entries|
        expect(entries.sole).to include("data_source" => "verified", "document_ids" => [ "DOC-#{document.id}" ])
      end
    end
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

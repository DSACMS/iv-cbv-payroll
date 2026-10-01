require "swagger_helper"

RSpec.describe ActivityReportSchemas do
  let(:document) { JSONSchemer.openapi(JSON.parse(RSpec.configuration.openapi_specs.fetch("openapi.json").to_json)) }
  let(:schema) { document.schema("CeActivityReport") }
  let(:payroll) do
    {
      "type" => "employment", "month" => "2026-07", "data_source" => "validated", "document_ids" => [],
      "applicant_full_name" => nil, "employer_name" => nil,
      "paystubs" => [ { "pay_date" => "2026-07-15", "pay_gross" => 12345, "pay_net" => nil,
        "deductions" => [ { "category" => nil, "tax" => "unknown", "amount" => nil } ],
        "gross_pay_list" => [ { "type" => "base", "amount" => 12345 } ] } ]
    }
  end
  let(:self_attested) do
    {
      "type" => "employment", "month" => "2026-07", "data_source" => "self_attested", "document_ids" => [],
      "employer_name" => "Sample work", "employment_type" => "self_employed", "is_self_employed" => true,
      "hours" => 12.75, "gross_income" => 123.45
    }
  end
  let(:report) do
    {
      "schema_version" => "1.0.0", "confirmation_code" => "EXAMPLE123", "completed_at" => "2026-08-11T14:00:00Z",
      "agency_partner_metadata" => { "first_name" => "Jane", "date_of_birth" => "1990-04-15" },
      "ce_report" => {
        "review_period" => { "start_month" => "2026-07", "end_month" => "2026-07" },
        "documents" => [],
        "activities" => { "community_service" => {}, "work_program" => {}, "employment" => { "2026-07" => [ self_attested, payroll ] } }
      }
    }
  end

  it "defines valid OpenAPI components without requiring an API operation" do
    standalone = JSONSchemer.openapi(JSON.parse({
      openapi: "3.1.0", info: { title: "CE reports", version: "v1" }, paths: {},
      components: { schemas: InvitationSchemas.schemas.merge(described_class.schemas) }
    }.to_json))

    expect(standalone.validate.to_a).to be_empty
    expect(standalone.schema("CeActivityReport").valid?(report)).to be(true)
  end

  it "accepts mixed employment with decimal self-attested dollars and nullable payroll data" do
    expect(schema.validate(report).to_a).to be_empty
  end

  it "accepts overlapping agency metadata shapes and validates their shared fields" do
    report["agency_partner_metadata"] = { "first_name" => "Jane", "last_name" => "Doe", "case_number" => "EXAMPLE-123" }
    expect(schema.valid?(report)).to be(true)

    report["agency_partner_metadata"]["case_number"] = 123
    expect(schema.valid?(report)).to be(false)
  end

  it "validates every month's entries, including months absent from documentation examples" do
    report["ce_report"]["activities"]["employment"]["2030-12"] = [ payroll.merge("paystubs" => [ { "pay_date" => "2030-12-01", "pay_gross" => "invalid" } ]) ]

    expect(schema.valid?(report)).to be(false)
  end

  it "requires arrays for month keys while allowing future non-month fields" do
    employment = report["ce_report"]["activities"]["employment"]
    employment["future_field"] = { "value" => true }
    expect(schema.valid?(report)).to be(true)

    employment["2026-08"] = { "value" => true }
    expect(schema.valid?(report)).to be(false)
  end

  it "distinguishes self-attested and validated employment using the data source" do
    payroll["data_source"] = "self_attested"
    expect(schema.valid?(report)).to be(false)
    payroll["data_source"] = "argyle"
    expect(schema.valid?(report)).to be(false)
  end

  it "rejects negative self-attested income and missing hours" do
    self_attested["gross_income"] = -1
    expect(schema.valid?(report)).to be(false)
    self_attested["gross_income"] = 0
    self_attested.delete("hours")
    expect(schema.valid?(report)).to be(false)
  end

  it "validates nested paystub deductions and gross pay components" do
    payroll["paystubs"].first["deductions"].first["amount"] = 12.34
    expect(schema.valid?(report)).to be(false)
    payroll["paystubs"].first["deductions"].first["amount"] = 1234
    payroll["paystubs"].first["gross_pay_list"].first.delete("type")
    expect(schema.valid?(report)).to be(false)
  end

  it "allows future fields on the report, activities, paystubs, and metadata" do
    report["future_field"] = true
    report["agency_partner_metadata"]["future_field"] = true
    report["ce_report"]["future_field"] = true
    report["ce_report"]["activities"]["future_activity"] = {}
    payroll["future_field"] = true
    payroll["paystubs"].first["future_field"] = true
    self_attested["future_field"] = true

    expect(schema.valid?(report)).to be(true)
  end

  it "uses the CE report guide for the standalone model description" do
    expect(described_class.schemas[:CeActivityReport][:description])
      .to eq(InvitationDocumentation.read("ce-activity-report", section: "Model"))
  end
end

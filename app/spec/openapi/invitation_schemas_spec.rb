require "rails_helper"
require_relative "invitation_schemas"

RSpec.describe InvitationSchemas do
  let(:document) do
    JSONSchemer.openapi(JSON.parse({
      openapi: "3.0.3", info: { title: "Test", version: "v1" }, paths: {},
      components: { schemas: described_class.schemas }
    }.to_json))
  end
  let(:sandbox) { { "first_name" => "Jane", "last_name" => "Doe", "middle_name" => nil, "case_number" => "EXAMPLE-123" } }
  let(:louisiana) { { "doc_id" => "EXAMPLE-DOC-123", "case_number" => nil, "date_of_birth" => "01/15/1990" } }

  it "defines separate sandbox and Louisiana field sets" do
    expect(document.schema("SandboxPartnerMetadata").valid?(sandbox)).to be(true)
    expect(document.schema("SandboxPartnerMetadata").valid?(louisiana)).to be(false)
    expect(document.schema("LouisianaPartnerMetadata").valid?(louisiana)).to be(true)
    expect(document.schema("LouisianaPartnerMetadata").valid?(sandbox)).to be(false)
  end

  it "requires sandbox applicant names" do
    schema = document.schema("SandboxPartnerMetadata")
    expect(schema.valid?(sandbox.except("first_name"))).to be(false)
    expect(schema.valid?(sandbox.merge("last_name" => nil))).to be(false)
  end

  it "limits Louisiana case numbers without limiting sandbox case numbers" do
    expect(document.schema("LouisianaPartnerMetadata").valid?(louisiana.merge("case_number" => "1" * 14))).to be(false)
    expect(document.schema("SandboxPartnerMetadata").valid?(sandbox.merge("case_number" => "1" * 14))).to be(true)
  end

  it "accepts overlapping agency shapes without requiring an exclusive match" do
    schema = document.schema("AgencyPartnerMetadata")
    expect(schema.valid?(sandbox)).to be(true)
    expect(schema.valid?(louisiana)).to be(true)
    expect(schema.valid?({ "case_number" => "EXAMPLE-123" })).to be(true)
    expect(schema.valid?(sandbox.merge("doc_id" => "EXAMPLE-DOC-123"))).to be(false)
  end
end

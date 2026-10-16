require "rails_helper"
require_relative "invitation_schemas"

RSpec.describe InvitationSchemas do
  let(:document) do
    JSONSchemer.openapi(JSON.parse({
      openapi: "3.1.0", info: { title: "Test", version: "v1" }, paths: {},
      components: { schemas: described_class.schemas }
    }.to_json))
  end
  let(:sandbox) { { "first_name" => "Jane", "last_name" => "Doe", "middle_name" => nil, "case_number" => "EXAMPLE-123" } }
  let(:louisiana) { { "doc_id" => "EXAMPLE-DOC-123", "case_number" => nil, "date_of_birth" => "01/15/1990" } }

  describe "V2 agency metadata" do
    let(:metadata) { { "individual_id" => "INDIVIDUAL-123", "first_name" => "Jane", "last_name" => "Doe" } }

    it "uses each agency's configured metadata and required fields for both invitation types" do
      agencies = {
        "Sandbox" => "sandbox", "NewHampshire" => "nh_dhhs", "Louisiana" => "la_ldh",
        "Research" => "research", "Accenture" => "accenture"
      }

      agencies.each do |name, id|
        agency = Rails.application.config.client_agencies[id]
        %w[community_engagement employment].each do |invitation_type|
          schema = described_class.schemas.fetch("AgencyMetadataV2#{name}#{invitation_type.camelize}")

          expect(schema[:properties].keys).to match_array(agency.api_metadata(invitation_type))
          expect(schema[:required]).to match_array(agency.api_required_metadata(invitation_type).map(&:to_s))
        end
      end
    end

    it "does not document date of birth for employment invitations" do
      schema = document.schema("AgencyMetadataV2SandboxEmployment")

      expect(described_class.schemas.fetch("AgencyMetadataV2SandboxEmployment")[:properties]).not_to have_key(:date_of_birth)
      expect(schema.valid?(metadata)).to be(true)
      expect(schema.valid?(metadata.except("individual_id"))).to be(false)
    end

    it "requires date of birth for community engagement invitations" do
      schema = document.schema("AgencyMetadataV2SandboxCommunityEngagement")

      expect(schema.valid?(metadata)).to be(false)
      expect(schema.valid?(metadata.merge("date_of_birth" => "01/15/1990"))).to be(true)
    end

    context "when one agency's configuration changes" do
      let(:agency) { Rails.application.config.client_agencies["sandbox"] }

      before do
        allow(agency).to receive(:api_metadata).and_call_original
        allow(agency).to receive(:api_required_metadata).and_call_original
        allow(agency).to receive(:api_metadata).with("employment").and_return(%i[individual_id case_number])
        allow(agency).to receive(:api_required_metadata).with("employment").and_return(%i[individual_id case_number])
      end

      it "updates only that agency's matching V2 schema" do
        schemas = described_class.schemas

        expect(schemas.fetch("AgencyMetadataV2SandboxEmployment")[:properties].keys).to contain_exactly(:individual_id, :case_number)
        expect(schemas.fetch("AgencyMetadataV2SandboxEmployment")[:required]).to contain_exactly("individual_id", "case_number")
        expect(schemas.fetch("AgencyMetadataV2SandboxCommunityEngagement")[:properties]).to have_key(:first_name)
        expect(schemas.fetch("AgencyMetadataV2LouisianaEmployment")[:properties]).to have_key(:first_name)
        expect(schemas.fetch("AgencyMetadataSandbox")[:properties]).to have_key(:middle_name)
      end
    end
  end

  it "defines separate sandbox and Louisiana field sets" do
    expect(document.schema("AgencyMetadataSandbox").valid?(sandbox)).to be(true)
    expect(document.schema("AgencyMetadataLouisiana").valid?(louisiana)).to be(true)
    expect(described_class.schemas["AgencyMetadataSandbox"][:properties].keys).to contain_exactly(:first_name, :middle_name, :last_name, :case_number, :date_of_birth)
    expect(described_class.schemas["AgencyMetadataLouisiana"][:properties].keys).to contain_exactly(:case_number, :date_of_birth, :doc_id)
  end

  it "requires first and last names specifically for New Hampshire" do
    schema = document.schema("AgencyMetadataNewHampshire")
    expect(schema.valid?(sandbox)).to be(true)
    expect(schema.valid?(sandbox.except("first_name"))).to be(false)
    expect(schema.valid?(sandbox.except("last_name"))).to be(false)
    expect(schema.valid?(sandbox.merge("last_name" => nil))).to be(false)
  end

  it "does not infer required fields for other agencies from their supported fields" do
    %w[Sandbox Louisiana Research Accenture].each do |agency|
      name = "AgencyMetadata#{agency}"
      expect(described_class.schemas[name]).not_to have_key(:required)
      expect(document.schema(name).valid?({})).to be(true)
    end
    expect(document.schema("AgencyMetadataSandbox").valid?(sandbox.except("first_name", "last_name"))).to be(true)
  end

  it "limits Louisiana case numbers without limiting sandbox case numbers" do
    expect(document.schema("AgencyMetadataLouisiana").valid?(louisiana.merge("case_number" => "1" * 14))).to be(false)
    expect(document.schema("AgencyMetadataSandbox").valid?(sandbox.merge("case_number" => "1" * 14))).to be(true)
  end

  it "uses AgencyMetadata-prefixed names for all agency model references and titles" do
    schemas = described_class.schemas
    names = %w[AgencyMetadataSandbox AgencyMetadataNewHampshire AgencyMetadataLouisiana AgencyMetadataResearch AgencyMetadataAccenture]

    expect(schemas[:AgencyPartnerMetadata][:anyOf]).to eq(names.map { |name| { "$ref" => "#/components/schemas/#{name}" } })
    names.each do |name|
      expect(schemas.fetch(name)[:title]).to eq(name)
    end
  end

  it "accepts overlapping agency shapes without requiring an exclusive match" do
    schema = document.schema("AgencyPartnerMetadata")
    expect(schema.valid?(sandbox)).to be(true)
    expect(schema.valid?(louisiana)).to be(true)
    expect(schema.valid?({ "case_number" => "EXAMPLE-123" })).to be(true)
    expect(schema.valid?(sandbox.merge("doc_id" => "EXAMPLE-DOC-123"))).to be(true)
  end

  it "explicitly allows additional properties on every object, including nested schemas" do
    check = lambda do |value|
      case value
      when Hash
        expect(value[:additionalProperties]).to be(true), "Object schema must allow future fields: #{value.inspect}" if value[:type] == :object
        value.each_value { |child| check.call(child) }
      when Array
        value.each { |child| check.call(child) }
      end
    end

    check.call(described_class.schemas)
  end

  it "does not advertise removed activity invitation fields or models" do
    schemas = described_class.schemas

    expect(schemas[:InvitationRequest][:properties]).not_to have_key(:activities)
    expect(schemas[:InvitationResponse][:properties]).not_to have_key(:activity_tokenized_url)
    expect(schemas.keys.grep(/InvitationActivity$/)).to be_empty
  end

  describe "community engagement invitations" do
    let(:schema) { document.schema("CommunityEngagementInvitationRequest") }
    let(:request) do
      {
        "language" => "en",
        "verification_range" => "last_complete_month",
        "agency_partner_metadata" => {
          "individual_id" => "EXAMPLE-123", "first_name" => "Jane", "last_name" => "Doe", "date_of_birth" => "1990-01-15"
        }
      }
    end

    it "references each agency's V2 community engagement metadata" do
      metadata = described_class.schemas[:CommunityEngagementInvitationRequest][:properties][:agency_partner_metadata]

      expect(metadata[:anyOf]).to contain_exactly(
        { "$ref" => "#/components/schemas/AgencyMetadataV2SandboxCommunityEngagement" },
        { "$ref" => "#/components/schemas/AgencyMetadataV2NewHampshireCommunityEngagement" },
        { "$ref" => "#/components/schemas/AgencyMetadataV2LouisianaCommunityEngagement" },
        { "$ref" => "#/components/schemas/AgencyMetadataV2ResearchCommunityEngagement" },
        { "$ref" => "#/components/schemas/AgencyMetadataV2AccentureCommunityEngagement" }
      )
    end

    it "requires community engagement metadata even when employment metadata is valid" do
      request["agency_partner_metadata"].delete("date_of_birth")

      expect(schema.valid?(request)).to be(false)
    end

    context "when an agency's community engagement metadata changes" do
      let(:agency) { Rails.application.config.client_agencies["sandbox"] }
      let(:request) { super().merge("agency_partner_metadata" => { "individual_id" => "EXAMPLE-123", "case_number" => "CASE-123" }) }

      before do
        allow(agency).to receive(:api_metadata).and_call_original
        allow(agency).to receive(:api_required_metadata).and_call_original
        allow(agency).to receive(:api_metadata).with("community_engagement").and_return(%i[individual_id case_number])
        allow(agency).to receive(:api_required_metadata).with("community_engagement").and_return(%i[individual_id case_number])
      end

      it "validates requests using the updated agency configuration" do
        expect(schema.valid?(request)).to be(true)
      end
    end

    it "allows the optional unpaid-work restriction to be omitted" do
      expect(schema.valid?(request)).to be(true)
    end

    it "allows a true restriction" do
      expect(schema.valid?(request.merge("unpaid_work_only" => true))).to be(true)
    end

    it "allows a false restriction" do
      expect(schema.valid?(request.merge("unpaid_work_only" => false))).to be(true)
    end

    it "allows a null restriction" do
      expect(schema.valid?(request.merge("unpaid_work_only" => nil))).to be(true)
    end

    it "rejects a string restriction" do
      expect(schema.valid?(request.merge("unpaid_work_only" => "true"))).to be(false)
    end
  end

  it "accepts future fields in requests, responses, metadata, and errors" do
    metadata = sandbox.merge("future_metadata" => { "value" => true })
    request = { "language" => "en", "agency_partner_metadata" => metadata, "future_request" => true }
    response = request.merge("tokenized_url" => "https://example.org/start/token", "expiration_date" => "2026-10-07T23:59:59-04:00", "future_response" => true)
    errors = { "errors" => [ { "field" => "language", "message" => "Invalid", "future_detail" => true } ], "future_error" => true }

    expect(document.schema("InvitationRequest").valid?(request)).to be(true)
    expect(document.schema("InvitationResponse").valid?(response)).to be(true)
    expect(document.schema("AgencyMetadataLouisiana").valid?(louisiana.merge("future_metadata" => true))).to be(true)
    expect(document.schema("InvitationErrors").valid?(errors)).to be(true)
  end
end

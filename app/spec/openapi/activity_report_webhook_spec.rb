require "swagger_helper"

RSpec.describe ActivityReportWebhook do
  let(:document) { RSpec.configuration.openapi_specs.fetch("openapi.json") }
  let(:operation) { document[:webhooks].fetch(described_class::PATH).fetch(:post) }

  it "documents an agency-hosted webhook under the receiving-data section" do
    # Rswag converts request-spec paths to OpenAPI 3.1 when its formatter finishes.
    expect(JSONSchemer.openapi(JSON.parse(document.merge(paths: {}).to_json)).validate.to_a).to be_empty
    expect(document[:paths]).not_to have_key(described_class::PATH)
    expect(operation[:tags]).to eq([ described_class::TAG ])
    expect(operation[:servers].first[:url]).to eq("https://agency.example.org")
    expect(operation[:security]).to eq([])
    expect(operation.dig(:requestBody, :content, "application/json", :schema))
      .to eq({ "$ref" => "#/components/schemas/CeActivityReport" })
  end

  it "reads the receiving section, delivery guidance, and samples from Markdown" do
    tag = document[:tags].find { |item| item[:name] == described_class::TAG }
    expect(tag[:description]).to eq(InvitationDocumentation.read("receiving-data/ce-activity-json", section: "Overview"))
    expect(operation[:description]).to include("[Webhook signatures](#tag/webhook-signatures)")
    expect(operation[:description]).not_to include("## cURL example", "## Signing headers")
    signatures = document[:tags].find { |item| item[:name] == "Webhook signatures" }
    expect(signatures[:description]).to eq(InvitationDocumentation.read("receiving-data/webhook-signatures"))
    receiving = document["x-tagGroups"].find { |group| group[:name] == "Receiving data from the Emmy Platform" }
    expect(receiving[:tags]).to include("Webhook signatures", described_class::TAG)
    expect(operation[:responses]["200"][:description]).to eq(InvitationDocumentation.read("receiving-data/ce-activity-json", section: "Response"))
  end

  it "starts the receiving-data section with the shared Markdown overview" do
    receiving = document["x-tagGroups"].find { |group| group[:name] == "Receiving data from the Emmy Platform" }
    expect(receiving[:tags].first).to eq("Overview")
    overview = document[:tags].find { |tag| tag[:name] == "Overview" }
    expect(overview[:description]).to eq(InvitationDocumentation.read("receiving-data/README", section: "Overview"))
  end
end

require "swagger_helper"

RSpec.describe DocumentWebhook do
  let(:document) { RSpec.configuration.openapi_specs.fetch("openapi.json") }
  let(:operation) { document[:webhooks].fetch(described_class::PATH).fetch(:post) }
  let(:headers) { operation[:parameters].index_by { |parameter| parameter[:name] } }

  it "publishes a valid agency-hosted webhook in the receiving-data navigation" do
    expect(JSONSchemer.openapi(JSON.parse(document.merge(paths: {}).to_json)).validate.to_a).to be_empty
    expect(document[:paths]).not_to have_key(described_class::PATH)
    expect(operation[:servers].first[:url]).to eq("https://agency.example.org")
    expect(operation[:security]).to eq([])
    expect(operation[:tags]).to eq([ described_class::TAG ])
    receiving = document["x-tagGroups"].find { |group| group[:name] == "Receiving data from the Emmy Platform" }
    expect(receiving[:tags]).to include(described_class::TAG)
  end

  it "accepts raw document bytes of any MIME type" do
    expect(operation[:requestBody][:required]).to be(true)
    expect(operation[:requestBody][:content]).to eq(
      "*/*" => { schema: { type: :string, format: :binary } }
    )
    expect(operation[:responses]["200"]).not_to have_key(:content)
  end

  it "requires content headers, signing headers, and the report confirmation code" do
    expect(headers.values).to all(include(in: :header))
    expect(headers.values.select { |header| header[:required] }.pluck(:name)).to contain_exactly(
      "Content-Type", "Content-Length", "X-IVAAS-Timestamp", "X-IVAAS-Signature", "X-IVAAS-Confirmation-Code"
    )
  end

  it "documents activity document headers without requiring them for income report PDFs" do
    expect(headers.values.reject { |header| header[:required] }.pluck(:name)).to contain_exactly(
      "Content-Disposition", "X-IVAAS-Document-Id"
    )
    expect(headers["Content-Disposition"][:description])
      .to eq(InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Content-Disposition"))
    expect(headers["X-IVAAS-Document-Id"][:description])
      .to eq(InvitationDocumentation.read("receiving-data/pdf-transmission", section: "X-IVAAS-Document-Id"))
  end

  it "reads the overview, delivery details, request, and response guidance from Markdown" do
    tag = document[:tags].find { |item| item[:name] == described_class::TAG }
    expect(tag[:description]).to eq(InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Overview"))
    expect(operation[:description]).to include(
      InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Receive a Document")
        .sub("(webhook-signatures.md)", "(#tag/webhook-signatures)")
    )
    expect(operation[:requestBody][:description]).to eq(InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Request body"))
    expect(operation[:responses]["200"][:description]).to eq(
      InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Response and error handling")
        .sub("(retry-logic.md)", "(#tag/retry-logic)")
    )
    expect(operation[:parameters].find { |header| header[:name] == "Content-Type" }[:description])
      .to eq(InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Content-Type"))
    expect(operation[:parameters].find { |header| header[:name] == "Content-Length" }[:description])
      .to eq(InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Content-Length"))
  end

  it "publishes retry guidance separately under receiving data" do
    receiving = document["x-tagGroups"].find { |group| group[:name] == "Receiving data from the Emmy Platform" }
    expect(receiving[:tags]).to include("Retry logic")
    retry_tag = document[:tags].find { |tag| tag[:name] == "Retry logic" }
    expect(retry_tag[:description]).to eq(InvitationDocumentation.read("receiving-data/retry-logic"))
    expect(operation[:description]).not_to include("## Retry logic", retry_tag[:description])
  end
end

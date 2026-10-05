require "swagger_helper"
require "open3"
require "tempfile"

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
    expect(tag[:description]).to eq(InvitationDocumentation.read("receiving-data/README"))
    expect(operation[:description]).to include(
      InvitationDocumentation.read("receiving-data/ce-activity-json", section: "Transmission"),
      InvitationDocumentation.read("receiving-data/ce-activity-json", section: "cURL example")
    )
    expect(operation[:responses]["200"][:description]).to eq(InvitationDocumentation.read("receiving-data/ce-activity-json", section: "Response"))
    expect(operation["x-codeSamples"].sole[:source]).to eq(described_class.code_block("cURL example", "bash"))
  end

  [ "", "\n" ].each do |trailing_newline|
    it "signs the exact file bytes in the cURL sample with #{trailing_newline.empty? ? 'no' : 'a'} trailing newline" do
      body = JSON.pretty_generate({ confirmation_code: "SYNTHETIC123" }) + trailing_newline
      Tempfile.create([ "ce-report", ".json" ]) do |file|
        file.write(body)
        file.flush
        # Capture cURL's arguments without making any HTTP request.
        script = "set -eu\ncurl() { printf '%s\\0' \"$@\"; }\n" + operation["x-codeSamples"].sole[:source]
        output, error, status = Open3.capture3({
          "AGENCY_API_KEY" => "synthetic-signing-key", "AGENCY_REPORT_URL" => "https://receiver.example.org/custom/v2/reports",
          "REPORT_FILE" => file.path
        }, "bash", "-c", script)

        expect(status.success?).to be(true), error
        arguments = output.split("\0")
        expect(arguments.first(3)).to eq([ "--request", "POST", "https://receiver.example.org/custom/v2/reports" ])
        expect(arguments.last(2)).to eq([ "--data-binary", "@#{file.path}" ])
        headers = arguments.each_cons(2).filter_map { |flag, value| value if flag == "--header" }
          .to_h { |header| header.split(": ", 2) }
        expect(headers["Content-Type"]).to eq("application/json")
        expect(headers["X-IVAAS-Confirmation-Code"]).to eq("SYNTHETIC123")
        expect(headers["X-IVAAS-Signature"])
          .to eq(JsonApiSignature.generate(body, headers.fetch("X-IVAAS-Timestamp"), "synthetic-signing-key"))
      end
    end
  end
end

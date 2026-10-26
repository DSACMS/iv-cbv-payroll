require "rails_helper"
require "open3"
require "tempfile"
require_relative "invitation_documentation"

RSpec.describe JsonApiSignature do
  let(:trailing_newline) { "" }
  let(:body) { JSON.pretty_generate({ confirmation_code: "SYNTHETIC123" }) + trailing_newline }
  let(:report_file) { Tempfile.new([ "ce-report", ".json" ]) }
  let(:script) do
    # Capture cURL's arguments without making any HTTP request.
    "curl() { printf '%s\\0' \"$@\"; }\n" +
      InvitationDocumentation.code_block("receiving-data/webhook-signatures", section: "cURL example", language: "bash")
  end
  let(:result) do
    Open3.capture3({
      "AGENCY_API_KEY" => "synthetic-signing-key", "AGENCY_REPORT_URL" => "https://receiver.example.org/custom/v2/reports",
      "REPORT_FILE" => report_file.path
    }, "bash", "-c", script)
  end
  let(:arguments) { result.first.split("\0") }
  let(:headers) do
    arguments.each_cons(2).filter_map { |flag, value| value if flag == "--header" }
      .to_h { |header| header.split(": ", 2) }
  end
  let(:expected_headers) do
    {
      "Content-Type" => "application/json",
      "X-IVAAS-Timestamp" => headers.fetch("X-IVAAS-Timestamp"),
      "X-IVAAS-Confirmation-Code" => "SYNTHETIC123",
      "X-IVAAS-Signature" => described_class.generate(body, headers.fetch("X-IVAAS-Timestamp"), "synthetic-signing-key")
    }
  end

  before do
    report_file.write(body)
    report_file.flush
  end

  after { report_file.close! }

  it "sends the file with the correct headers and signature" do
    expect(result.last.success?).to be(true), result[1]
    expect(arguments.first(3)).to eq([ "--request", "POST", "https://receiver.example.org/custom/v2/reports" ])
    expect(arguments.last(2)).to eq([ "--data-binary", "@#{report_file.path}" ])
    expect(headers).to eq(expected_headers)
  end

  context "with a trailing newline in the JSON file" do
    let(:trailing_newline) { "\n" }

    it "includes the newline in the signed file bytes" do
      expect(result.last.success?).to be(true), result[1]
      expect(arguments.last(2)).to eq([ "--data-binary", "@#{report_file.path}" ])
      expect(headers).to eq(expected_headers)
    end
  end
end

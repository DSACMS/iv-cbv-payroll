require "rails_helper"
require_relative "invitation_documentation"
require_relative "invitation_schemas"

RSpec.describe InvitationDocumentation do
  it "reads the overview and operation descriptions from the docs directory" do
    %w[overview post-v1-invitations].each do |name|
      expect(described_class.read(name)).to eq(Rails.root.join("../docs/api/#{name}.md").read.strip)
      expect(described_class.read(name)).not_to be_empty
    end
  end

  it "uses Markdown for the metadata and response schema descriptions" do
    schemas = InvitationSchemas.schemas
    expect(schemas[:AgencyPartnerMetadata][:description]).to eq(described_class.read("agency-partner-metadata"))
    expect(schemas[:InvitationResponse][:description]).to eq(described_class.read("post-v1-invitations", section: "Response"))
  end

  it "reads an endpoint section without including its heading or neighboring sections" do
    description = described_class.read("post-v1-invitations", section: "Description")
    response = described_class.read("post-v1-invitations", section: "Response")

    expect(description).to start_with("Create a personalized income reporting link.")
    expect(description).not_to include("## Response", "14 days for the sandbox")
    expect(response).to start_with("Direct the applicant to `tokenized_url`")
    expect(response).not_to include("## Response", "idempotency")
  end

  it "fails clearly when a requested section is missing" do
    expect { described_class.read("post-v1-invitations", section: "Missing") }
      .to raise_error(ArgumentError, 'Missing section "Missing" in docs/api/post-v1-invitations.md')
  end

  it "rereads the file rather than caching its content" do
    path = Rails.root.join("../docs/api/overview.md")
    allow(Rails.root).to receive(:join).with("../docs/api", "overview.md").and_return(path)
    allow(path).to receive(:read).and_return("First version\n", "Updated version\n")

    expect(described_class.read("overview")).to eq("First version")
    expect(described_class.read("overview")).to eq("Updated version")
  end

  it "fails when a documentation source is missing" do
    expect { described_class.read("missing-invitation-documentation") }.to raise_error(Errno::ENOENT)
  end
end

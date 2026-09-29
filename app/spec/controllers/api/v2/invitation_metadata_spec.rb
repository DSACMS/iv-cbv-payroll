require "rails_helper"

RSpec.describe Api::V2::InvitationMetadata do
  subject(:contract) do
    described_class.new(
      params: ActionController::Parameters.new(
        agency_partner_metadata: metadata
      ),
      client_agency_id: client_agency_id,
      flow_type: flow_type
    )
  end

  let(:client_agency_id) { "sandbox" }
  let(:flow_type) { "community_engagement" }
  let(:metadata) do
    {
      individual_id: "IND123",
      first_name: "Jane",
      last_name: "Doe",
      unexpected: "discard me"
    }
  end

  it "permits configured metadata fields" do
    expect(contract.permitted.to_h).to eq(
      "individual_id" => "IND123",
      "first_name" => "Jane",
      "last_name" => "Doe"
    )
  end

  it "rejects unconfigured fields" do
    expect(contract.permitted).not_to have_key("unexpected")
  end

  it "has no errors when community engagement metadata is complete" do
    expect(contract.errors).to be_empty
  end

  context "when required metadata is missing" do
    let(:metadata) do
      {
        individual_id: "IND123",
        first_name: "Jane"
      }
    end

    it "returns errors for the missing fields" do
      expect(contract.errors.map { |error| error[:field] })
        .to contain_exactly(:last_name)
    end
  end
end

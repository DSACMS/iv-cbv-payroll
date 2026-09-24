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
      date_of_birth: "1977-09-13",
      unexpected: "discard me"
    }
  end

  it "permits configured metadata fields" do
    expect(contract.permitted.to_h).to eq(
      "individual_id" => "IND123",
      "first_name" => "Jane",
      "last_name" => "Doe",
      "date_of_birth" => "1977-09-13"
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
        .to contain_exactly(:last_name, :date_of_birth)
    end
  end

  context "for employment invitations" do
    let(:flow_type) { "employment" }
    let(:metadata) do
      {
        individual_id: "IND123",
        first_name: "Jane",
        last_name: "Doe",
        unexpected: "discard me"
      }
    end

    it "permits configured employment metadata" do
      expect(contract.errors).to be_empty
      expect(contract.permitted.to_h).to include(
        "individual_id" => "IND123",
        "first_name" => "Jane",
        "last_name" => "Doe"
      )
    end
  end

  context "for LA LDH employment invitations" do
    let(:client_agency_id) { "la_ldh" }
    let(:flow_type) { "employment" }

    let(:metadata) do
      {
        individual_id: "IND123",
        first_name: "Jane",
        last_name: "Doe"
      }
    end

    it "accepts individual_id" do
      expect(contract.errors).to be_empty
    end

    context "when both indentifiers are missing" do
      let(:metadata) do
        {
          date_of_birth: "1977-09-13"
        }
      end

      it "returns the agency-specific identifier error" do
        expect(contract.errors).to include(
          field: :individual_id,
          message_key: "api.v2.la_ldh.fields.individual_id.blank"
        )
      end
    end
  end
end

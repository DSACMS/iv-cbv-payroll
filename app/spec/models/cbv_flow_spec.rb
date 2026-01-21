require 'rails_helper'

RSpec.describe CbvFlow, type: :model do
  let(:cbv_flow) { create(:cbv_flow) }
  let(:client_agency_id) { "sandbox" }

  describe ".create_from_invitation" do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "ABC1234" }) }

    it "copies over relevant fields" do
      cbv_flow = described_class.create_from_invitation(cbv_flow_invitation, "test_device_id")
      expect(cbv_flow).to have_attributes(cbv_applicant: cbv_flow_invitation.cbv_applicant)
    end
  end

  describe "#to_generic_url" do
    context "with valid client agency ID" do
      context "in production environment" do
        before do
          stub_client_agency_config_value("sandbox", "agency_domain", "sandbox.reportmyincome.org")
        end

        it "returns simplified URL with production domain" do
          expected_url = "https://sandbox.reportmyincome.org/en"
          expect(cbv_flow.to_generic_url).to eq(expected_url)
        end

        it "includes origin parameter when provided" do
          expected_url = "https://sandbox.reportmyincome.org/en?origin=shared"
          expect(cbv_flow.to_generic_url(origin: "shared")).to eq(expected_url)
        end
      end

      context "in non-production environment" do
        before do
          stub_client_agency_config_value("sandbox", "agency_domain", "sandbox-verify-demo.navapbc.cloud")
        end

        it "returns simplified URL with demo domain" do
          expected_url = "https://sandbox-verify-demo.navapbc.cloud/en"
          expect(cbv_flow.to_generic_url).to eq(expected_url)
        end
      end
    end

    context "with invalid client agency ID" do
      let(:cbv_flow) { build(:cbv_flow, cbv_applicant_attributes: { client_agency_id: "invalid_agency" }) }

      it "raises ArgumentError" do
        expect { cbv_flow.to_generic_url }.to raise_error(
          ArgumentError, "Client Agency invalid_agency not found"
        )
      end
    end

    context "with missing host configuration" do
      before do
        stub_client_agency_config_value("sandbox", "agency_domain", nil)
      end

      it "returns uses the Rails runtime host" do
        expected_url = "http://localhost/en/cbv/links/sandbox"
        expect(cbv_flow.to_generic_url).to eq(expected_url)
      end

      it "includes origin parameter in path-based URL when provided" do
        expected_url = "http://localhost/en/cbv/links/sandbox?origin=shared"
        expect(cbv_flow.to_generic_url(origin: "shared")).to eq(expected_url)
      end
    end
  end

  describe "#fully_synced_payroll_accounts" do
    let(:payroll_accounts) do
      [
        build(:payroll_account),
        build(:payroll_account, :pinwheel_fully_synced),
        build(:payroll_account, :argyle_sync_in_progress),
        build(:payroll_account, :argyle_fully_synced)
      ]
    end

    it "returns only those payroll accounts that have fully synced" do
      allow(cbv_flow).to receive(:payroll_accounts).and_return(payroll_accounts)

      result = cbv_flow.fully_synced_payroll_accounts

      expect(result).to all(be_has_fully_synced)
      expect(result).not_to be_empty
    end
  end
end

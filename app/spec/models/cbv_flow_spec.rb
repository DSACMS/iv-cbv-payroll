
require 'rails_helper'

RSpec.describe CbvFlow, type: :model do
  describe ".create_from_invitation" do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "ABC1234" }) }

    it "copies over relevant fields" do
      cbv_flow = CbvFlow.create_from_invitation(cbv_flow_invitation)
      expect(cbv_flow).to have_attributes(
        cbv_applicant: cbv_flow_invitation.cbv_applicant,
        client_agency_id: "sandbox"
      )
    end
  end

  describe "#to_generic_url" do
    let(:cbv_flow) { create(:cbv_flow, client_agency_id: client_agency_id) }

    context "with valid client agency ID" do
      let(:client_agency_id) { "sandbox" }

      context "in production environment" do
        before do
          allow(Rails.env).to receive(:production?).and_return(true)
        end

        it "returns URL with production domain" do
          expected_url = "https://sandbox.reportmyincome.org/en/cbv/links/sandbox"
          expect(cbv_flow.to_generic_url).to eq(expected_url)
        end
      end

      context "in non-production environment" do
        before do
          allow(Rails.env).to receive(:production?).and_return(false)
        end

        it "returns URL with demo domain" do
          expected_url = "https://sandbox-verify-demo.navapbc.cloud/en/cbv/links/sandbox"
          expect(cbv_flow.to_generic_url).to eq(expected_url)
        end
      end
    end

    context "with invalid client agency ID" do
      let(:cbv_flow) { build(:cbv_flow, client_agency_id: "invalid_agency") }

      it "raises ArgumentError" do
        expect { cbv_flow.to_generic_url }.to raise_error(
          ArgumentError, "Client Agency invalid_agency not found"
        )
      end
    end
  end
end

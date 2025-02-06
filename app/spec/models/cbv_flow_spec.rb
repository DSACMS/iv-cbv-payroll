require 'rails_helper'

RSpec.describe CbvFlow, type: :model do
  describe ".create_from_invitation" do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "ABC1234" }) }

    it "copies over relevant fields" do
      cbv_flow = CbvFlow.create_from_invitation(cbv_flow_invitation)
      expect(cbv_flow).to have_attributes(
        cbv_applicant: cbv_flow_invitation.cbv_applicant,
        site_id: "sandbox"
      )
    end
  end
end

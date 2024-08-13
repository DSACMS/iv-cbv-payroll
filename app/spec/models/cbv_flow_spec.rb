require 'rails_helper'

RSpec.describe CbvFlow, type: :model do
  describe ".create_from_invitation" do
    let(:cbv_flow_invitation) { CbvFlowInvitation.create!(
      first_name: "John",
      middle_name: "Doe",
      last_name: "Smith",
      case_number: "ABC1234",
      site_id: "sandbox",
      email_address: "test@test.com",
      snap_application_date: Date.today
    ) }

    it "copies over relevant fields" do
      cbv_flow = CbvFlow.create_from_invitation(cbv_flow_invitation)
      expect(cbv_flow).to have_attributes(case_number: "ABC1234", site_id: "sandbox")
    end
  end
end

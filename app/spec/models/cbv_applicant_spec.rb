require 'rails_helper'

RSpec.describe CbvApplicant, type: :model do
  describe '.create_from_invitation' do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }

    it 'creates a new CbvApplicant with attributes from cbv_flow_invitation' do
      cbv_applicant = CbvApplicant.create_from_invitation(cbv_flow_invitation)
      expect(cbv_applicant).to be_persisted
      expect(cbv_applicant.case_number).to eq(cbv_flow_invitation.case_number)
      expect(cbv_applicant.first_name).to eq(cbv_flow_invitation.first_name)
      expect(cbv_applicant.middle_name).to eq(cbv_flow_invitation.middle_name)
      expect(cbv_applicant.last_name).to eq(cbv_flow_invitation.last_name)
      expect(cbv_applicant.agency_id_number).to eq(cbv_flow_invitation.agency_id_number)
      expect(cbv_applicant.client_id_number).to eq(cbv_flow_invitation.client_id_number)
      expect(cbv_applicant.snap_application_date).to eq(cbv_flow_invitation.snap_application_date)
      expect(cbv_applicant.beacon_id).to eq(cbv_flow_invitation.beacon_id)
    end

    it 'associates the CbvApplicant with the CbvFlowInvitation' do
      cbv_applicant = CbvApplicant.create_from_invitation(cbv_flow_invitation)
      cbv_flow_invitation.reload
      expect(cbv_flow_invitation.cbv_applicant).to eq(cbv_applicant)
    end
  end
end

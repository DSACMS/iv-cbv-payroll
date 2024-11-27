require 'rails_helper'

RSpec.describe CbvClient, type: :model do
  describe '.create_from_invitation' do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }

    it 'creates a new CbvClient with attributes from cbv_flow_invitation' do
      cbv_client = CbvClient.create_from_invitation(cbv_flow_invitation)
      expect(cbv_client).to be_persisted
      expect(cbv_client.case_number).to eq(cbv_flow_invitation.case_number)
      expect(cbv_client.first_name).to eq(cbv_flow_invitation.first_name)
      expect(cbv_client.middle_name).to eq(cbv_flow_invitation.middle_name)
      expect(cbv_client.last_name).to eq(cbv_flow_invitation.last_name)
      expect(cbv_client.agency_id_number).to eq(cbv_flow_invitation.agency_id_number)
      expect(cbv_client.client_id_number).to eq(cbv_flow_invitation.client_id_number)
      expect(cbv_client.snap_application_date).to eq(cbv_flow_invitation.snap_application_date)
      expect(cbv_client.beacon_id).to eq(cbv_flow_invitation.beacon_id)
    end

    it 'associates the CbvClient with the CbvFlowInvitation' do
      cbv_client = CbvClient.create_from_invitation(cbv_flow_invitation)
      cbv_flow_invitation.reload
      expect(cbv_flow_invitation.cbv_client).to eq(cbv_client)
    end

    context 'when cbv_flow_invitation is nil' do
      it 'raises an error' do
        expect {
          CbvClient.create_from_invitation(nil)
        }.to raise_error(NoMethodError)
      end
    end
  end
end

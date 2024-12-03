namespace :backfills do
  desc "Back-fill cbv_clients from existing cbv data"
  task cbv_clients: :environment do
    CbvFlowInvitation.transaction do
      CbvFlowInvitation.find_each do |cbv_flow_invitation|
        cbv_client = CbvClient.create_from_invitation(cbv_flow_invitation)
        cbv_flow_invitation.cbv_flows.update_all(cbv_client_id: cbv_client.id)
      end
    end
  end
end

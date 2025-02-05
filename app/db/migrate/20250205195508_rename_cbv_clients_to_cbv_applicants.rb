class RenameCbvClientsToCbvApplicants < ActiveRecord::Migration[7.1]
  def change
    rename_table :cbv_clients, :cbv_applicants
    rename_column :cbv_flows, :cbv_client_id, :cbv_applicant_id
    rename_column :cbv_flow_invitations, :cbv_client_id, :cbv_applicant_id
  end
end

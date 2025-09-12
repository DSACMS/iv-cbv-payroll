class AddCbvFlowInvitationIdToCbvApplicant < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :cbv_applicants, :cbv_flow_invitation, foreign_key: true, index: { algorithm: :concurrently }
  end
end

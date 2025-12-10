class CreateActivityFlowInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_flow_invitations do |t|
      t.string :auth_token
      t.string :client_agency_id
      t.references :cbv_applicant, foreign_key: true
      t.string :reference_id

      t.timestamps
    end

    add_index :activity_flow_invitations, :auth_token, unique: true
    add_reference :activity_flows, :activity_flow_invitation, foreign_key: true
  end
end

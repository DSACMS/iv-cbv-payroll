class CreateCbvFlowInvitation < ActiveRecord::Migration[7.0]
  def change
    create_table :cbv_flow_invitations do |t|
      t.string :email_address
      t.string :case_number
      t.string :auth_token

      t.timestamps
    end
  end
end

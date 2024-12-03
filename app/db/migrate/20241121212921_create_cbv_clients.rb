class CreateCbvClients < ActiveRecord::Migration[7.1]
  def change
    create_table :cbv_clients do |t|
      t.string :case_number
      t.string "first_name", null: false
      t.string "middle_name"
      t.string "last_name", null: false
      t.string "agency_id_number"
      t.string "client_id_number"
      t.date "snap_application_date", null: false
      t.string "beacon_id"
      t.datetime "redacted_at"
      t.timestamps
    end
    add_reference :cbv_flows, :cbv_client
    add_reference :cbv_flow_invitations, :cbv_client
  end
end

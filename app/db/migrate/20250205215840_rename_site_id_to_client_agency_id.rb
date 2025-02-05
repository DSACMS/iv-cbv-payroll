class RenameSiteIdToClientAgencyId < ActiveRecord::Migration[7.0]
  def change
    rename_column :cbv_flows, :site_id, :client_agency_id
    rename_column :users, :site_id, :client_agency_id
    rename_column :cbv_flow_invitations, :site_id, :client_agency_id

    # Update the index name and columns
    remove_index :users, name: "index_users_on_email_and_site_id"
    add_index :users, [:email, :client_agency_id], unique: true, name: "index_users_on_email_and_client_agency_id"
  end
end

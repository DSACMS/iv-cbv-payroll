class RenameSiteIdToClientAgencyId < ActiveRecord::Migration[7.0]
  def change
    # First rename the columns
    rename_column :cbv_flows, :site_id, :client_agency_id
    rename_column :users, :site_id, :client_agency_id
    rename_column :cbv_flow_invitations, :site_id, :client_agency_id

    # Then handle the index - Rails will automatically handle the reversal
    remove_index :users, [:email, :site_id] if index_exists?(:users, [:email, :site_id])
    add_index :users, [:email, :client_agency_id], unique: true unless index_exists?(:users, [:email, :client_agency_id])
  end
end

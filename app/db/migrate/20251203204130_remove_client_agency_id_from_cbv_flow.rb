class RemoveClientAgencyIdFromCbvFlow < ActiveRecord::Migration[7.2]
  def change
    remove_column :cbv_flows, :client_agency_id, :string
  end
end

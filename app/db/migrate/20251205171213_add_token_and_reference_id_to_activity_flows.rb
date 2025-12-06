class AddTokenAndReferenceIdToActivityFlows < ActiveRecord::Migration[7.2]
  def change
    add_column :activity_flows, :token, :string
    add_column :activity_flows, :reference_id, :string
    add_index :activity_flows, :token, unique: true
  end
end

class AddCbvFlowColumnsToActivityFlow < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flows, :argyle_user_id, :string
    add_column :activity_flows, :end_user_id, :uuid, default: 'gen_random_uuid()', null: false
    add_column :activity_flows, :additional_information, :jsonb, default: {}
  end
end

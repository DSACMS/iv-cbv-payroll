class AddSiteIdToCbvFlowObjects < ActiveRecord::Migration[7.1]
  def change
    change_table :cbv_flows do |t|
      t.string :site_id
    end

    change_table :cbv_flow_invitations do |t|
      t.string :site_id
    end
  end
end

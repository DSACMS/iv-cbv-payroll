class AddHasOtherJobsToCbvFlow < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flows, :has_other_jobs, :boolean, default: false
  end
end

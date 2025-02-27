class RenameColumn < ActiveRecord::Migration[7.1]
  def change
    rename_column :cbv_flows, :pinwheel_end_user_id, :end_user_id
  end
end

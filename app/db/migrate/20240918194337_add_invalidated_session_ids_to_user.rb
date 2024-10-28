class AddInvalidatedSessionIdsToUser < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :invalidated_session_ids, :jsonb
  end
end

class ChangeUserUniqueConstraint < ActiveRecord::Migration[7.1]
  def change
    remove_index :users, name: "index_users_on_email"
    add_index :users, [ :email, :site_id ], unique: true
  end
end

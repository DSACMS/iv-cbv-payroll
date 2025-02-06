class AddIsServiceAccountToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :is_service_account, :boolean, default: false
  end
end

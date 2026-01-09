class AddConfirmationCodeToActivityFlow < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flows, :confirmation_code, :string
  end
end

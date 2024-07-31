class AddConfirmationCodeToCbvFlow < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flows, :confirmation_code, :string
  end
end

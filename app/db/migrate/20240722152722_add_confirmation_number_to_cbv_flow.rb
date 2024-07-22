class AddConfirmationNumberToCbvFlow < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flows, :confirmation_number, :string
  end
end

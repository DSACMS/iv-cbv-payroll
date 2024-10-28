class CreateCbvFlows < ActiveRecord::Migration[7.0]
  def change
    create_table :cbv_flows do |t|
      t.string :case_number
      t.string :argyle_user_id

      t.timestamps
    end
  end
end

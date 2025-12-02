class CreateActivityFlows < ActiveRecord::Migration[7.2]
  def change
    create_table :activity_flows do |t|
      t.timestamps
    end
  end
end

class CreateWebhookEvent < ActiveRecord::Migration[7.1]
  def change
    create_table :webhook_events do |t|
      t.string :event_name
      t.string :event_outcome
      t.references :payroll_account, null: false, foreign_key: true

      t.timestamps
    end
  end
end

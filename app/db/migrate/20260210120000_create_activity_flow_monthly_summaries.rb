# frozen_string_literal: true

class CreateActivityFlowMonthlySummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_flow_monthly_summaries do |t|
      t.references :activity_flow, null: false, foreign_key: true
      t.references :payroll_account, null: false, foreign_key: true
      t.date :month, null: false
      t.decimal :total_w2_hours, precision: 10, scale: 2, default: 0
      t.decimal :total_gig_hours, precision: 10, scale: 2, default: 0
      t.integer :accrued_gross_earnings_cents, default: 0
      t.decimal :total_mileage, precision: 10, scale: 2, default: 0
      t.integer :paychecks_count, default: 0
      t.string :employer_name
      t.string :employment_type
      t.datetime :redacted_at

      t.timestamps
    end

    add_index :activity_flow_monthly_summaries,
              %i[activity_flow_id payroll_account_id month],
              unique: true,
              name: "index_activity_flow_monthly_summaries_on_flow_account_month"
    add_index :activity_flow_monthly_summaries, %i[activity_flow_id month]
  end
end

# frozen_string_literal: true

class CreateActivityFlowEmploymentSummaries < ActiveRecord::Migration[8.1]
  def up
    create_table :activity_flow_employment_summaries do |t|
      t.references :activity_flow, null: false, foreign_key: true
      t.references :payroll_account, null: false, foreign_key: true
      t.string :employer_name
      t.string :employment_type
      t.string :employer_phone_number
      t.string :employer_address
      t.string :employment_status
      t.date :employment_start_date
      t.date :employment_termination_date
      t.datetime :redacted_at

      t.timestamps
    end

    add_index :activity_flow_employment_summaries,
              %i[activity_flow_id payroll_account_id],
              unique: true,
              name: "index_activity_flow_employment_summaries_on_flow_account"

    execute <<~SQL.squish
      INSERT INTO activity_flow_employment_summaries (
        activity_flow_id,
        payroll_account_id,
        employer_name,
        employment_type,
        redacted_at,
        created_at,
        updated_at
      )
      SELECT DISTINCT ON (activity_flow_id, payroll_account_id)
        activity_flow_id,
        payroll_account_id,
        employer_name,
        employment_type,
        redacted_at,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM activity_flow_monthly_summaries
      ORDER BY activity_flow_id, payroll_account_id, employer_name IS NULL, month DESC
    SQL

    remove_column :activity_flow_monthly_summaries, :employer_name, :string
    remove_column :activity_flow_monthly_summaries, :employment_type, :string
  end

  def down
    add_column :activity_flow_monthly_summaries, :employer_name, :string
    add_column :activity_flow_monthly_summaries, :employment_type, :string

    execute <<~SQL.squish
      UPDATE activity_flow_monthly_summaries
      SET employer_name = activity_flow_employment_summaries.employer_name,
          employment_type = activity_flow_employment_summaries.employment_type
      FROM activity_flow_employment_summaries
      WHERE activity_flow_monthly_summaries.activity_flow_id = activity_flow_employment_summaries.activity_flow_id
        AND activity_flow_monthly_summaries.payroll_account_id = activity_flow_employment_summaries.payroll_account_id
    SQL

    drop_table :activity_flow_employment_summaries
  end
end

# frozen_string_literal: true

class AddCompensationFieldsToActivityFlowEmploymentSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_employment_summaries, :pay_frequency, :string
    add_column :activity_flow_employment_summaries, :compensation_amount, :integer
    add_column :activity_flow_employment_summaries, :compensation_unit, :string
  end
end

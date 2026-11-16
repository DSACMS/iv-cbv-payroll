class AddEmployerAddressFieldsToActivityFlowEmploymentSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_employment_summaries, :employer_address_line1, :string
    add_column :activity_flow_employment_summaries, :employer_address_line2, :string
    add_column :activity_flow_employment_summaries, :employer_address_city, :string
    add_column :activity_flow_employment_summaries, :employer_address_state, :string
    add_column :activity_flow_employment_summaries, :employer_address_postal_code, :string
  end
end

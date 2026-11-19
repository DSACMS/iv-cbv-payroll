class RemoveEmployerAddressFieldsFromActivityFlowEmploymentSummaries < ActiveRecord::Migration[8.1]
  def change
    remove_column :activity_flow_employment_summaries, :employer_address_line1
    remove_column :activity_flow_employment_summaries, :employer_address_line2
    remove_column :activity_flow_employment_summaries, :employer_address_city
    remove_column :activity_flow_employment_summaries, :employer_address_state
    remove_column :activity_flow_employment_summaries, :employer_address_postal_code
  end
end

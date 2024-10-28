class ChangeAdditionalInformationToJsonbColumnOnCbvFlows < ActiveRecord::Migration[7.1]
  def change
    remove_column :cbv_flows, :additional_information
    add_column :cbv_flows, :additional_information, :jsonb, default: {}
  end
end

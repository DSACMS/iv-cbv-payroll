class AddAdditionalInformationToCbvFlow < ActiveRecord::Migration[7.0]
  def change
    add_column :cbv_flows, :additional_information, :text
  end
end

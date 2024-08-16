class AddConsentedToAuthUseAtToCbvFlows < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flows, :consented_to_authorized_use_at, :datetime
  end
end

class AddRenewalRequiredMonthsToActivityFlows < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flows, :renewal_required_months, :integer
  end
end

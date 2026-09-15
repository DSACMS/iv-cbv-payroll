class AddIndividualIdToCbvApplicant < ActiveRecord::Migration[8.1]
  def change
    add_column :cbv_applicants, :individual_id, :string
  end
end

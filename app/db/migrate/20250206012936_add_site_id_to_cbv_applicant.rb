class AddSiteIdToCbvApplicant < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_applicants, :site_id, :string
  end
end

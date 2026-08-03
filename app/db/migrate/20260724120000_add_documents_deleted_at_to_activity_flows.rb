class AddDocumentsDeletedAtToActivityFlows < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flows, :documents_deleted_at, :datetime
  end
end

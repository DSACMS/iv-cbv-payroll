class AddDocIdIndexingFieldToLaLdh < ActiveRecord::Migration[7.2]
  def change
    change_table :cbv_applicants do |t|
      t.string :doc_id
    end
  end
end

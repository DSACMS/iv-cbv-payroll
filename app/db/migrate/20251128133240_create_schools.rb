class CreateSchools < ActiveRecord::Migration[7.2]
  def change
    create_table :schools do |t|
      t.belongs_to :identity, null: false, foreign_key: true
      t.string :name
      t.string :address

      t.timestamps
    end
  end
end

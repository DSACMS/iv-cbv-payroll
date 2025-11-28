class CreateIdentities < ActiveRecord::Migration[7.2]
  def change
    create_table :identities do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.date :date_of_birth, null: false

      t.timestamps

      t.index [:first_name, :last_name, :date_of_birth], unique: true
    end
  end
end

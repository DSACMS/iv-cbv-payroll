# frozen_string_literal: true

class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      t.string :auth_token, null: false
      t.string :reference_id, null: false
      t.string :client_agency_id, null: false

      t.timestamps
    end

    add_index :households, :auth_token, unique: true
    add_index :households, :reference_id, unique: true

    create_table :household_members do |t|
      t.references :household, null: false, foreign_key: true
      t.references :activity_flow_invitation, null: false, foreign_key: true, index: { unique: true }
      t.string :reference_id, null: false
      t.string :display_name, null: false
      t.string :role_label, null: false

      t.timestamps
    end

    add_index :household_members, %i[household_id reference_id], unique: true
  end
end

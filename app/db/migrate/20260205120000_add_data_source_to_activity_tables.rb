# frozen_string_literal: true

class AddDataSourceToActivityTables < ActiveRecord::Migration[8.0]
  def change
    add_column :volunteering_activities, :data_source, :string, default: "self_attested", null: false
    add_column :job_training_activities, :data_source, :string, default: "self_attested", null: false
    add_column :education_activities, :data_source, :string, default: "validated", null: false
  end
end

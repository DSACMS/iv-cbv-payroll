class CreateNscEnrollmentTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :nsc_enrollment_terms do |t|
      t.string :enrollment_status, null: false
      t.string :school_name
      t.string :first_name
      t.string :middle_name
      t.string :last_name
      t.date :term_begin
      t.date :term_end

      t.references :education_activity

      t.timestamps
    end
  end
end

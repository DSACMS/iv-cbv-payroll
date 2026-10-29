class RemoveNscWithdrawnFromNscEnrollmentTerms < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE nsc_enrollment_terms
      SET enrollment_status = 'withdrawn'
      WHERE nsc_withdrawn = TRUE
    SQL

    remove_column :nsc_enrollment_terms, :nsc_withdrawn
  end

  def down
    add_column :nsc_enrollment_terms, :nsc_withdrawn, :boolean, default: false

    execute <<~SQL
      UPDATE nsc_enrollment_terms
      SET nsc_withdrawn = TRUE, enrollment_status = 'unknown'
      WHERE enrollment_status = 'withdrawn'
    SQL
  end
end

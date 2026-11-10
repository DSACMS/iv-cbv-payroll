class AddSupplementalEnrollmentStatusToNscEnrollmentTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :nsc_enrollment_terms, :supplemental_enrollment_status, :string
  end
end

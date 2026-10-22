class AddSchoolCertifiedOnToNscEnrollmentTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :nsc_enrollment_terms, :school_certified_on, :date
  end
end

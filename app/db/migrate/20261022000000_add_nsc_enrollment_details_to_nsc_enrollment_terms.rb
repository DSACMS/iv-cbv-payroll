class AddNscEnrollmentDetailsToNscEnrollmentTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :nsc_enrollment_terms, :school_certified_on, :date
    add_column :nsc_enrollment_terms, :nsc_withdrawn, :boolean, default: false
  end
end

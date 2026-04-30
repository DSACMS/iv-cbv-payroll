class AddCreditHoursToNscEnrollmentTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :nsc_enrollment_terms, :credit_hours, :integer
  end
end

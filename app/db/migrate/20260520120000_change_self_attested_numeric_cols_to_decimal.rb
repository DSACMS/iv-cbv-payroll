class ChangeSelfAttestedNumericColsToDecimal < ActiveRecord::Migration[8.1]
  def up
    change_column :employment_activity_months,   :hours,         :decimal, precision: 10, scale: 2
    change_column :employment_activity_months,   :gross_income,  :decimal, precision: 10, scale: 2
    change_column :education_activity_months,    :hours,         :decimal, precision: 10, scale: 2
    change_column :volunteering_activity_months, :hours,         :decimal, precision: 10, scale: 2
    change_column :job_training_activity_months, :hours,         :decimal, precision: 10, scale: 2
    change_column :nsc_enrollment_terms,         :credit_hours,  :decimal, precision: 10, scale: 2
  end

  def down
    change_column :employment_activity_months,   :hours,         :integer
    change_column :employment_activity_months,   :gross_income,  :integer
    change_column :education_activity_months,    :hours,         :integer
    change_column :volunteering_activity_months, :hours,         :integer
    change_column :job_training_activity_months, :hours,         :integer
    change_column :nsc_enrollment_terms,         :credit_hours,  :integer
  end
end

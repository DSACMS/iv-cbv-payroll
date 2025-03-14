class ChangeNullConstraintForCbvApplicant < ActiveRecord::Migration[7.1]
  def change
    change_column_null :cbv_applicants, :first_name, true
    change_column_null :cbv_applicants, :last_name, true
    change_column_null :cbv_applicants, :snap_application_date, true
  end
end

class AddDateOfBirthToCbvApplicant < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_applicants, :date_of_birth, :date
  end
end

class AddDraftToActivitiesAndPayrollAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :volunteering_activities, :draft, :boolean, default: false, null: false
    add_column :job_training_activities, :draft, :boolean, default: false, null: false
    add_column :employment_activities, :draft, :boolean, default: false, null: false
    add_column :education_activities, :draft, :boolean, default: false, null: false
    add_column :payroll_accounts, :draft, :boolean, default: false, null: false
  end
end

class AddRedactedAtToCeRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_flow_invitations, :redacted_at, :datetime
    add_column :activity_flows, :redacted_at, :datetime
    add_column :household_members, :redacted_at, :datetime
    add_column :households, :redacted_at, :datetime
    add_column :identities, :redacted_at, :datetime
    add_column :education_activities, :redacted_at, :datetime
    add_column :employment_activities, :redacted_at, :datetime
    add_column :job_training_activities, :redacted_at, :datetime
    add_column :volunteering_activities, :redacted_at, :datetime
    add_column :nsc_enrollment_terms, :redacted_at, :datetime
    add_column :employment_activity_months, :redacted_at, :datetime
  end
end

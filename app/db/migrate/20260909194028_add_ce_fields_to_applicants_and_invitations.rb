class AddCeFieldsToApplicantsAndInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :cbv_applicants, :individual_id, :string
    add_column :activity_flow_invitations, :expires_at, :datetime
    add_column :activity_flow_invitations, :language, :string
    add_reference :activity_flow_invitations, :user, null: true, foreign_key: true
  end
end

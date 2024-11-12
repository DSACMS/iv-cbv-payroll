class AddInvitationReminderSentAtColumnToCbvFlowInvitation < ActiveRecord::Migration[7.1]
  def change
    add_column :cbv_flow_invitations, :invitation_reminder_sent_at, :datetime
  end
end

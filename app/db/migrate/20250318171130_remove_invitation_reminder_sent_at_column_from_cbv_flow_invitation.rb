class RemoveInvitationReminderSentAtColumnFromCbvFlowInvitation < ActiveRecord::Migration[7.1]
  def change
    remove_column :cbv_flow_invitations, :invitation_reminder_sent_at, :datetime
  end
end

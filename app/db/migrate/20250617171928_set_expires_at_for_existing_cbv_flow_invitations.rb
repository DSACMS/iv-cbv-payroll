class SetExpiresAtForExistingCbvFlowInvitations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    CbvFlowInvitation.in_batches(of: 1000) do |batch|
      batch.each do |invitation|
        next if invitation.expires_at.present?
        invitation.update_columns(expires_at: invitation.send(:calculate_expires_at))
      end
    end
  end
end

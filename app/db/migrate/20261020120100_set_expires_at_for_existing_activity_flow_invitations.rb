class SetExpiresAtForExistingActivityFlowInvitations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    ActivityFlowInvitation.reset_column_information
    ActivityFlowInvitation.where(expires_at: nil).find_each do |invitation|
      # Skip invitations for client agencies that no longer exist.
      next unless Rails.application.config.client_agencies[invitation.client_agency_id]

      invitation.update_columns(expires_at: invitation.send(:calculate_expires_at))
    end
  end

  def down
    # Expiration values should be preserved until the column is removed.
  end
end

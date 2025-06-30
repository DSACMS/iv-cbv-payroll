class SetExpiresAtForExistingCbvFlowInvitations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    CbvFlowInvitation.in_batches(of: 1000) do |batch|
      batch.each do |invitation|
        next if invitation.expires_at.present?

        # Skip invitations for client agencies that no longer exist
        client_agency = Rails.application.config.client_agencies[invitation.client_agency_id]
        next if client_agency.nil?

        invitation.update_columns(expires_at: invitation.send(:calculate_expires_at))
      end
    end
  end
end

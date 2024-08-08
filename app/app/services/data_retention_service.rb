# This class is responsible for redacting data on all models in accordance with
# our data retention policy.
class DataRetentionService
  # Redact unstarted invitations 7 days after they expire
  REDACT_UNUSED_INVITATIONS_AFTER = 7.days

  def redact_invitations
    CbvFlowInvitation
      .unstarted
      .find_each do |record|
        record.redact! if Time.now.after?(record.expires_at + REDACT_UNUSED_INVITATIONS_AFTER)
      end
  end
end

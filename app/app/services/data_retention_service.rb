# This class is responsible for redacting data on all models in accordance with
# our data retention policy.
class DataRetentionService
  # Redact unstarted and incomplete invitations 7 days after they expire
  REDACT_UNUSED_INVITATIONS_AFTER = 7.days

  # Redact transmitted CbvFlows 7 days after they are sent to caseworker
  REDACT_TRANSMITTED_CBV_FLOWS_AFTER = 7.days

  def redact_all!
    redact_invitations
    redact_incomplete_cbv_flows
    redact_complete_cbv_flows
  end

  def redact_invitations
    CbvFlowInvitation
      .unstarted
      .unredacted
      .find_each do |cbv_flow_invitation|
        next unless Time.now.after?(cbv_flow_invitation.expires_at + REDACT_UNUSED_INVITATIONS_AFTER)

        cbv_flow_invitation.redact!
        cbv_flow_invitation.cbv_applicant&.redact!
      end
  end

  def redact_incomplete_cbv_flows
    CbvFlow
      .incomplete
      .unredacted
      .includes(:cbv_flow_invitation)
      .find_each do |cbv_flow|
        if cbv_flow.cbv_flow_invitation.present?
          # Redact CbvFlow records (together with their invitations) some period
          # after the invitation expires.
          invitation_redact_at = cbv_flow.cbv_flow_invitation.expires_at + REDACT_UNUSED_INVITATIONS_AFTER
          next unless Time.now.after?(invitation_redact_at)

          cbv_flow.redact!
          cbv_flow.cbv_flow_invitation.redact!
          cbv_flow.cbv_applicant&.redact!
        else
          # Redact standalone CbvFlow records some period after their last
          # update.
          #
          # Although the CbvFlow is not updated on every page, sessions time out
          # after 30 minutes, so it would be extremely unlikely for a valid
          # session to still be in progress after 7 days.
          flow_redact_at = cbv_flow.updated_at + REDACT_UNUSED_INVITATIONS_AFTER
          next unless Time.now.after?(flow_redact_at)

          cbv_flow.redact!
          cbv_flow.cbv_applicant&.redact!
        end
      end
  end

  def redact_complete_cbv_flows
    CbvFlow
      .unredacted
      .where("transmitted_at < ?", REDACT_TRANSMITTED_CBV_FLOWS_AFTER.ago)
      .includes(:cbv_flow_invitation)
      .find_each do |cbv_flow|
        cbv_flow.redact!
        cbv_flow.cbv_flow_invitation.redact! if cbv_flow.cbv_flow_invitation.present?
        cbv_flow.cbv_applicant&.redact!
      end
  end

  # Use after conducting a user test or other time we want to manually redact a
  # specific person's data in the system.
  def self.manually_redact_by_case_number!(case_number)
    applicant = CbvApplicant.find_by!(case_number: case_number)
    applicant.redact!
    applicant.cbv_flow_invitations.map(&:redact!)
    applicant.cbv_flows.map(&:redact!)
  end
end

# This class is responsible for redacting data on all models in accordance with
# our data retention policy.
class DataRetentionService
  # Redact unstarted invitations 7 days after they expire
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
      .find_each do |cbv_flow_invitation|
        cbv_flow_invitation.redact! if Time.now.after?(cbv_flow_invitation.expires_at + REDACT_UNUSED_INVITATIONS_AFTER)
      end
  end

  def redact_incomplete_cbv_flows
    CbvFlow
      .incomplete
      .includes(:cbv_flow_invitation)
      .find_each do |cbv_flow|
        invitation_redact_at = cbv_flow.cbv_flow_invitation.expires_at + REDACT_UNUSED_INVITATIONS_AFTER

        cbv_flow.redact! if Time.now.after?(invitation_redact_at)
        cbv_flow.cbv_flow_invitation.redact! if cbv_flow.cbv_flow_invitation.present?
      end
  end

  def redact_complete_cbv_flows
    CbvFlow
      .where("transmitted_at < ?", REDACT_TRANSMITTED_CBV_FLOWS_AFTER.ago)
      .includes(:cbv_flow_invitation)
      .find_each do |cbv_flow|
        cbv_flow.redact!
        cbv_flow.cbv_flow_invitation.redact! if cbv_flow.cbv_flow_invitation.present?
      end
  end
end

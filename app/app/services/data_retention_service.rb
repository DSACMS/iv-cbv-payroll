# This class is responsible for redacting data on all models in accordance with
# our data retention policy.
class DataRetentionService
  # Redact unstarted and incomplete invitations 7 days after they expire
  REDACT_UNUSED_INVITATIONS_AFTER = 7.days

  # Redact transmitted CbvFlows 7 days after they are sent to caseworker
  REDACT_TRANSMITTED_CBV_FLOWS_AFTER = 7.days

  # Redact records that were created more than 30 days that are unredacted, regardless of other conditions
  REDACT_OLD_RECORD_BACKSTOP = 30.days

  def redact_all!
    redact_invitations
    redact_incomplete_cbv_flows
    redact_transmitted_cbv_flows
    redact_old_cbv_flows
  end

  # redact invitations and their associated applicants if the invitation has not been started, has not been redacted,
  # and it is 7 days after the invitation expires
  def redact_invitations
    CbvFlowInvitation
      .unstarted
      .unredacted
      .find_each do |cbv_flow_invitation|
        next unless Time.current.after?(cbv_flow_invitation.expires_at + REDACT_UNUSED_INVITATIONS_AFTER)

        cbv_flow_invitation.redact!
        cbv_flow_invitation.cbv_applicant&.redact!
      end
  end

  # redact cbv flows, invitations, applicants, and payroll accounts for cbv flows that have been started, are unredacted,
  # and it is 7 days after the invitation expires (for those with an invitation) or it is 7 days after the most
  # recent update for a generic cbv flow
  def redact_incomplete_cbv_flows
    CbvFlow
      .incomplete
      .unredacted
      .includes(:cbv_flow_invitation, :payroll_accounts)
      .find_each do |cbv_flow|
        if cbv_flow.cbv_flow_invitation.present?
          # Redact CbvFlow records (together with their invitations) some period
          # after the invitation expires.
          invitation_redact_at = cbv_flow.cbv_flow_invitation.expires_at + REDACT_UNUSED_INVITATIONS_AFTER
          next unless Time.current.after?(invitation_redact_at)

          cbv_flow.redact!
          cbv_flow.cbv_flow_invitation.redact!
          cbv_flow.cbv_applicant&.redact!
          cbv_flow.payroll_accounts.each(&:redact!)
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
          cbv_flow.payroll_accounts.each(&:redact!)
        end
      end
  end

  # redact flows that are unredacted and have been transmitted 7 days after they are transmitted
  def redact_transmitted_cbv_flows
    CbvFlow
      .unredacted
      .where("transmitted_at < ?", REDACT_TRANSMITTED_CBV_FLOWS_AFTER.ago)
      .includes(:cbv_flow_invitation, :payroll_accounts)
      .find_each do |cbv_flow|
        cbv_flow.redact!
        cbv_flow.cbv_flow_invitation.redact! if cbv_flow.cbv_flow_invitation.present?
        cbv_flow.cbv_applicant&.redact!
        cbv_flow.payroll_accounts.each(&:redact!)
      end
  end

  # redact flows that are unredacted and were created more than 30 days ago
  def redact_old_cbv_flows
    CbvFlow
      .unredacted
      .where("created_at < ?", REDACT_OLD_RECORD_BACKSTOP.ago)
      .includes(:cbv_flow_invitation, :payroll_accounts)
      .find_each do |cbv_flow|
      cbv_flow.redact!
      cbv_flow.cbv_flow_invitation.redact! if cbv_flow.cbv_flow_invitation.present?
      cbv_flow.cbv_applicant&.redact!
      cbv_flow.payroll_accounts.each(&:redact!)
    end
  end

  # Use after conducting a user test or other time we want to manually redact a
  # specific person's data in the system.
  def self.manually_redact_by_case_number!(case_number)
    applicant = CbvApplicant.find_by!(case_number: case_number)
    applicant.redact!
    applicant.cbv_flow_invitations.map(&:redact!)
    applicant.cbv_flows.map(&:redact!)
    applicant.cbv_flows.each { |cbv_flow| cbv_flow.payroll_accounts.each(&:redact!) }
  end

  # retroactive redaction for case numbers by agency
  # TODO: This is a one off. Should be updated to just be something like retroactive_redact(agency_id,field_name)
  def self.redact_case_numbers_by_agency(agency_id)
    applicants = CbvApplicant.where(client_agency_id: agency_id)
    applicants.find_each(batch_size: 200) do |applicant|
      applicant.redact!({ case_number: :string })
    end
    puts "Redacted #{applicants.length} applicants"
  end
end

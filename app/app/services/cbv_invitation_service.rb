class CbvInvitationService
  def invite(cbv_flow_invitation_params, current_user)
    ActiveRecord::Base.transaction do
      cbv_flow_invitation = CbvFlowInvitation.create!(cbv_flow_invitation_params.merge(user: current_user))
      send_invitation_email(cbv_flow_invitation)
      track_event(cbv_flow_invitation, current_user)
      cbv_flow_invitation
    end
  rescue StandardError => e
    log_error(e)
    raise
  end

  private

  def track_event(cbv_flow_invitation, current_user)
    NewRelicEventTracker.track("ApplicantInvitedToFlow", {
      timestamp: Time.now.to_i,
      user_id: current_user.id,
      site_id: cbv_flow_invitation.site_id,
      invitation_id: cbv_flow_invitation.id
    })
  end

  def send_invitation_email(cbv_flow_invitation)
    ApplicantMailer.with(cbv_flow_invitation: cbv_flow_invitation).invitation_email.deliver_now
  end

  def log_error(error)
    Rails.logger.error("Error inviting applicant: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
  end
end

namespace :invitation_reminders do
  desc "Send invitation reminders"
  task send_all: :environment do
    CbvFlowInvitation
      .where(invitation_reminder_sent_at: nil)
      .where("created_at <= ?", 3.days.ago)
      .find_each do |invitation|
        next if invitation.expired?
        next if invitation.complete?

        ApplicantMailer.with(
          cbv_flow_invitation: invitation
        ).invitation_reminder_email.deliver_now
        invitation.touch(:invitation_reminder_sent_at)
      end
  end
end

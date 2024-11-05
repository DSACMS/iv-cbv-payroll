namespace :invitation_reminders do
  desc "Send invitation reminders"
  task send_all: :environment do
    CbvFlowInvitation
      .where(invitation_reminder_sent_at: nil)
      .where('created_at <= ?', 3.days.ago)
      .where(redacted_at: nil)
      .find_each do |invitation|
        next if invitation.expired?
        next if invitation.complete?

        puts "Invitation ID: #{invitation.id}"
        puts "  Email: #{invitation.email_address}"
        puts "  Created: #{invitation.created_at}"
        puts "  SNAP app date: #{invitation.snap_application_date}"
        puts "  Case Number: #{invitation.case_number}"
        puts "  Reminder sent: #{invitation.invitation_reminder_sent_at}"
        puts "---"

        unless invitation.update!(invitation_reminder_sent_at: Time.now)
          Rails.logger.error("update error!")
        end
        ApplicantMailer.with(cbv_flow_invitation: invitation).invitation_reminder_email.deliver_now
      end
  end
end

# Preview all emails at http://localhost:3000/rails/mailers/applicant_mailer
class ApplicantMailerPreview < BaseMailerPreview
  include ViewHelper

  def invitation_email_dta
    ApplicantMailer.with(
      cbv_flow_invitation: FactoryBot.create(:cbv_flow_invitation, :ma)
    ).invitation_email
  end

  def invitation_email_nyc
    ApplicantMailer.with(
      cbv_flow_invitation: FactoryBot.create(:cbv_flow_invitation, :nyc)
    ).invitation_email
  end
end

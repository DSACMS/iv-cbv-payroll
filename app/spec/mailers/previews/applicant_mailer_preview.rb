# Preview all emails at http://localhost:3000/rails/mailers/applicant_mailer
class ApplicantMailerPreview < BaseMailerPreview
  include ReportViewHelper

  def invitation_email_dta
    ApplicantMailer.with(
      cbv_flow_invitation: FactoryBot.create(:cbv_flow_invitation, :ma, user: unique_user, language: I18n.locale)
    ).invitation_email
  end

  def invitation_email_nyc
    ApplicantMailer.with(
      cbv_flow_invitation: FactoryBot.create(:cbv_flow_invitation, :nyc, user: unique_user, language: I18n.locale)
    ).invitation_email
  end

  private
  def unique_user
    FactoryBot.create(:user, email: "#{SecureRandom.uuid}@example.com")
  end
end

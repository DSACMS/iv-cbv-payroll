class ApplicantMailer < ApplicationMailer
  helper :view
  before_action :set_params

  def invitation_email
    mail(
      to: @cbv_flow_invitation.email_address,
      subject: I18n.t("applicant_mailer.invitation_email.subject")
    )
  end

  private

  def set_params
    @cbv_flow_invitation = params[:cbv_flow_invitation]
  end
end

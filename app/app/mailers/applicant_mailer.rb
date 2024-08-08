class ApplicantMailer < ApplicationMailer
  helper :view
  before_action :set_params

  def invitation_email
    mail(
      to: @email_address,
      subject: I18n.t("applicant_mailer.invitation_email.subject")
    )
  end

  private

  def set_params
    @email_address = params[:email_address]
    @link = params[:link] if params[:link]
  end
end

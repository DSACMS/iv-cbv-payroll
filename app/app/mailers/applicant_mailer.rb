class ApplicantMailer < ApplicationMailer
  helper :view, :application
  helper_method :current_agency
  before_action :set_params
  around_action :set_locale
  def invitation_email
    mail(
      to: @cbv_flow_invitation.email_address,
      subject: view_context.agency_translation("applicant_mailer.invitation_email.subject")
    )
  end

  def invitation_reminder_email
    mail(
      to: @cbv_flow_invitation.email_address,
      subject: view_context.agency_translation("applicant_mailer.invitation_reminder_email.subject")
    )
  end

  private

  def set_locale(&action)
    I18n.with_locale(@cbv_flow_invitation.language, &action)
  end

  def set_params
    @cbv_flow_invitation = params[:cbv_flow_invitation]
  end

  def current_agency
    client_agency_config[@cbv_flow_invitation.client_agency_id]
  end
end

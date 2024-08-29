class ApplicantMailer < ApplicationMailer
  helper :view, :application
  helper_method :current_site
  before_action :set_params

  def invitation_email
    mail(
      to: @cbv_flow_invitation.email_address,
      subject: view_context.site_translation("applicant_mailer.invitation_email.subject")
    )
  end

  private

  def set_params
    @cbv_flow_invitation = params[:cbv_flow_invitation]
  end

  def current_site
    site_config[@cbv_flow_invitation.site_id]
  end
end

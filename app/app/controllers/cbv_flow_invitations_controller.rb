class CbvFlowInvitationsController < ApplicationController
  protect_from_forgery prepend: true
  before_action :ensure_valid_params!
  before_action :authenticate_user!

  def new
    @site_id = sanitized_site_id
    @cbv_flow_invitation = CbvFlowInvitation.new
  end

  def create
    begin
      CbvInvitationService.new.invite(
        cbv_flow_invitation_params[:email_address],
        cbv_flow_invitation_params[:case_number],
        sanitized_site_id
      )
    rescue => ex
      flash[:alert] = t(".invite_failed",
                        email_address: cbv_flow_invitation_params[:email_address],
                        error_message: ex.message
                       )
      Rails.logger.error("Error sending CBV invitation: #{ex.class} - #{ex.message}")
      return redirect_to new_invitation_path(secret: params[:secret])
    end

    flash[:notice] = t(".invite_success", email_address: cbv_flow_invitation_params[:email_address])
    redirect_to root_url
  end

  private

  def ensure_valid_params!
    if site_config.site_ids.exclude?(sanitized_site_id)
      flash[:alert] = t("cbv_flow_invitations.incorrect_site_id")
      redirect_to root_url
    end
  end

  def cbv_flow_invitation_params
    params.fetch(:cbv_flow_invitation, {}).permit(
      :email_address,
      :case_number
    )
  end

  def sanitized_site_id
    sanitize_site_id(params[:site_id])
  end

  def sanitize_site_id(site_id)
    # Sanitize the site_id to prevent directory traversal attacks
    site_id.to_s.gsub(/\A\//, '').gsub(/\A\.\.\//, '').gsub(/\/\.\.\//, '/')
  end
end

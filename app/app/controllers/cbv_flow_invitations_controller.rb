class CbvFlowInvitationsController < ApplicationController
  before_action :ensure_password!

  def new
    @cbv_flow_invitation = CbvFlowInvitation.new
  end

  def create
    begin
      CbvInvitationService.new.invite(
        cbv_flow_invitation_params[:email_address],
        cbv_flow_invitation_params[:case_number]
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

  def ensure_password!
    return if params[:secret] == ENV["CBV_INVITE_SECRET"]

    flash[:alert] = t("cbv_flow_invitations.incorrect_invite_secret")
    redirect_to root_url
  end

  def cbv_flow_invitation_params
    params.fetch(:cbv_flow_invitation, {}).permit(
      :email_address,
      :case_number
    )
  end
end

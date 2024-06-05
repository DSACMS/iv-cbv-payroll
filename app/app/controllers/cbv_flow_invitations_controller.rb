class CbvFlowInvitationsController < ApplicationController
  before_action :ensure_password!

  def new
    @cbv_flow_invitation = CbvFlowInvitation.new
  end

  def create
    CbvInvitationService.new.invite(
      cbv_flow_invitation_params[:email_address],
      cbv_flow_invitation_params[:case_number]
    )

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

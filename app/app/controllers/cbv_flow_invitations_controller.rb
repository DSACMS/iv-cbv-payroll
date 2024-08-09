class CbvFlowInvitationsController < Cbv::BaseController
  protect_from_forgery prepend: true
  before_action :ensure_valid_params!
  before_action :authenticate_user!

  def new
    @site_id = site_id
    @cbv_flow_invitation = CbvFlowInvitation.new
  end

  def create
    begin
      invitation_params = base_params.merge(site_specific_params)
      CbvInvitationService.new.invite(invitation_params)
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
    if site_config.site_ids.exclude?(site_id)
      flash[:alert] = t("cbv_flow_invitations.incorrect_site_id")
      redirect_to root_url
    end
  end

  def base_params
    cbv_flow_invitation_params.slice(
      :first_name,
      :middle_name,
      :last_name,
      :email_address,
      :snap_application_date
    ).merge(site_id: site_id)
  end

  def site_specific_params
    case site_id
    when "ma"
      cbv_flow_invitation_params.slice(:agency_id_number, :beacon_id)
    when "nyc"
      cbv_flow_invitation_params.slice(:client_id_number, :case_number)
    else
      {}
    end
  end

  def cbv_flow_invitation_params
    params.fetch(:cbv_flow_invitation, {}).permit(
      :first_name,
      :middle_name,
      :last_name,
      :client_id_number,
      :case_number,
      :email_address,
      :snap_application_date,
      :agency_id_number,
      :beacon_id
    )
  end

  def site_id
    params[:site_id]
  end
end

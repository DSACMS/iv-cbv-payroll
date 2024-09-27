class Caseworker::CbvFlowInvitationsController < Caseworker::BaseController
  protect_from_forgery prepend: true
  before_action :ensure_valid_params!
  before_action :authenticate_user!

  def new
    @site_id = site_id
    @cbv_flow_invitation = CbvFlowInvitation.new(site_id: site_id)

    if @site_id == "ma"
      @cbv_flow_invitation.snap_application_date ||= Date.today
    end
  end

  def create
    invitation_params = base_params.merge(site_specific_params)

    # handle errors from the mail service
    begin
      @cbv_flow_invitation = CbvInvitationService.new.invite(invitation_params, current_user)
    rescue => e
      flash[:alert] = t(".invite_failed",
                        email_address: cbv_flow_invitation_params[:email_address],
                        error_message: e.message)
      return redirect_to caseworker_dashboard_path(site_id: params[:site_id])
    end

    if @cbv_flow_invitation.errors.any?
      error_count = @cbv_flow_invitation.errors.size
      error_header = "#{helpers.pluralize(error_count, 'error')} occurred"

      # Collect error messages without attribute names
      error_messages = @cbv_flow_invitation.errors.messages.values.flatten.map { |msg| "<li>#{msg}</li>" }.join
      error_messages = "<ul>#{error_messages}</ul>"

      flash[:alert_heading] = error_header
      flash[:alert] = error_messages.html_safe

      return render :new
    end

    flash[:slim_alert] = {
      message: t(".invite_success", email_address: cbv_flow_invitation_params[:email_address]),
      type: "success"
    }
    redirect_to caseworker_dashboard_path(site_id: params[:site_id])
  end

  private

  def ensure_valid_params!
    if site_config.site_ids.exclude?(site_id)
      flash[:alert] = t("caseworker.cbv_flow_invitations.incorrect_site_id")
      redirect_to root_url
    end
  end

  def base_params
    cbv_flow_invitation_params.slice(
      :first_name,
      :middle_name,
      :language,
      :last_name,
      :email_address,
      :snap_application_date,
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
      :language,
      :last_name,
      :client_id_number,
      :case_number,
      :email_address,
      :snap_application_date,
      :agency_id_number,
      :beacon_id,
    )
  end

  def site_id
    params[:site_id]
  end
end

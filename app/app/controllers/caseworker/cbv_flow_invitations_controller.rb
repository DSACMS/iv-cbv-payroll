class Caseworker::CbvFlowInvitationsController < Caseworker::BaseController
  protect_from_forgery prepend: true
  before_action :ensure_valid_params!
  before_action :authenticate_user!
  helper_method :language_options

  def new
    @client_agency_id = client_agency_id
    @cbv_flow_invitation = CbvFlowInvitation.new(client_agency_id: client_agency_id)

    if @client_agency_id == "ma"
      @cbv_flow_invitation.snap_application_date ||= Date.today
    end
  end

  def create
    invitation_params = base_params.merge(client_agency_specific_params)
    # handle errors from the mail service
    begin
      @cbv_flow_invitation = CbvInvitationService.new(event_logger).invite(
        invitation_params,
        current_user,
        delivery_method: :email
      )
    rescue => e
      Rails.logger.error("Error inviting applicant: #{e.message}")
      flash[:alert] = t(".invite_failed",
                        email_address: cbv_flow_invitation_params[:email_address],
                        error_message: e.message)
      return redirect_to caseworker_dashboard_path(client_agency_id: params[:client_agency_id])
    end

    if @cbv_flow_invitation.errors.any?
      error_count = @cbv_flow_invitation.errors.size
      error_header = "#{helpers.pluralize(error_count, 'error')} occurred"

      # Collect error messages without attribute names
      error_messages = @cbv_flow_invitation.errors.messages.values.flatten.map { |msg| "<li>#{msg}</li>" }.join
      error_messages = "<ul>#{error_messages}</ul>"

      flash.now[:alert_heading] = error_header
      flash.now[:alert] = error_messages.html_safe

      return render :new, status: :unprocessable_entity
    end

    # hydrate the cbv_client with the invitation if there are no cbv_flow_invitation errors
    @cbv_client = CbvClient.create_from_invitation(@cbv_flow_invitation)

    flash[:slim_alert] = {
      message: t(".invite_success", email_address: cbv_flow_invitation_params[:email_address]),
      type: "success"
    }
    redirect_to caseworker_dashboard_path(client_agency_id: params[:client_agency_id])
  end

  private

  def language_options
    CbvFlowInvitation::VALID_LOCALES.each_with_object({}) do |lang, options|
      options[lang] = I18n.t(".shared.languages.#{lang}", default: lang.to_s.titleize)
    end
  end

  def ensure_valid_params!
    if client_agency_config.client_agency_ids.exclude?(client_agency_id)
      flash[:alert] = t("caseworker.cbv_flow_invitations.incorrect_client_agency_id")
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
    ).merge(client_agency_id: client_agency_id)
  end

  def client_agency_specific_params
    case client_agency_id
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

  def client_agency_id
    params[:client_agency_id]
  end
end

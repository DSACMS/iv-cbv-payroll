class Api::InvitationsController < ApplicationController
  skip_forgery_protection

  def create
    invitation_params = base_params.merge(site_specific_params)
    @cbv_flow_invitation = CbvInvitationService.new(event_logger).invite(invitation_params, _service_account_user_shim)

    if @cbv_flow_invitation.errors.any?
      return render json: @cbv_flow_invitation.errors, status: :unprocessable_entity
    end

    # hydrate the cbv_client with the invitation if there are no cbv_flow_invitation errors
    # this is an old refactor
    @cbv_client = CbvClient.create_from_invitation(@cbv_flow_invitation)

    render json: { **@cbv_flow_invitation.as_json, url: @cbv_flow_invitation.to_url }, status: :created
  end

  # todo: remove this shim, replace with real user
  def _service_account_user_shim
    User.new(email: "service@account.com", site_id: site_id)
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

  # can these be inferred from the model?
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

  # can these be inferred from the model?
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

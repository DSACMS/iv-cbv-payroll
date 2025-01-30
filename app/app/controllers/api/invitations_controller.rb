class Api::InvitationsController < ApplicationController
  skip_forgery_protection

  def create
    if service_account_user.nil?
      return render json: { error: "User not found" }, status: :unprocessable_entity
    end

    @cbv_flow_invitation = CbvInvitationService.new(event_logger).invite(cbv_flow_invitation_params, service_account_user)

    if @cbv_flow_invitation.errors.any?
      return render json: @cbv_flow_invitation.errors, status: :unprocessable_entity
    end

    @cbv_client = CbvClient.create_from_invitation(@cbv_flow_invitation)

    render json: {
      url: @cbv_flow_invitation.to_url,
      expiration_date: @cbv_flow_invitation.expires_at,
      language: @cbv_flow_invitation.language
    }, status: :created
  end

  # todo: replace with inference via API_KEY
  def service_account_user
    User.find_by(id: cbv_flow_invitation_params[:user_id])
  end

  # can these be inferred from the model?
  def cbv_flow_invitation_params
    params.permit(
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
      :user_id,
      :site_id
    )
  end

  def site_id
    cbv_flow_invitation_params[:site_id]
  end
end

class Api::InvitationsController < ApplicationController
  skip_forgery_protection

  before_action :authenticate

  def create
    @cbv_flow_invitation = CbvInvitationService.new(event_logger).invite(cbv_flow_invitation_params, @current_user, delivery_method: nil)

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
      :client_agency_id
    )
  end

  def client_agency_id
    cbv_flow_invitation_params[:client_agency_id]
  end

  private

  def authenticate
    authenticate_or_request_with_http_token do |token, options|
      @current_user = User.find_by_access_token(token)
    end
  end
end

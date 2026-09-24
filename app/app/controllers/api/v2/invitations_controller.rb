class Api::V2::InvitationsController < Api::InvitationsController
  def create
    contract = metadata_contract

    if contract.errors.any?
      return render json: {
        errors: contract.errors.map do |error|
          {
            field: error[:field],
            message: I18n.t(error[:message_key])
          }
        end
      }, status: :unprocessable_content
    end

    @cbv_flow_invitation = CbvInvitationService.new(event_logger).invite(
      cbv_flow_invitation_params(contract),
      @current_user,
      delivery_method: nil
    )

    return render_validation_errors unless @cbv_flow_invitation.errors.empty?

    if community_engagement?
      @activity_flow_invitation = CbvInvitationService.new(event_logger)
        .invite_to_activity_flow(
          @cbv_flow_invitation, [], verification_range: params[:verification_range], context: :v2
        )

      return render_validation_errors(@activity_flow_invitation) unless @activity_flow_invitation.errors.empty?
    end

    render_created_response
  end

  private

  def metadata_contract
    @metadata_contract ||= Api::V2::InvitationMetadata.new(
      params: params,
      client_agency_id: @current_user.client_agency_id,
      flow_type: params[:invitation_type]
    )
  end

  def cbv_flow_invitation_params(contract)
    permitted = params.permit(:language)

    permitted.deep_merge(
      client_agency_id: @current_user.client_agency_id,
      email_address: @current_user.email,
      cbv_applicant_attributes:  {
        client_agency_id: @current_user.client_agency_id,
        **contract.permitted.to_h
      }
    )
  end

  def community_engagement?
    params[:invitation_type] == "community_engagement"
  end

  def render_created_response
    response_body = {
      tokenized_url: @cbv_flow_invitation.to_url,
      token: @cbv_flow_invitation.auth_token,
      expiration_date: @cbv_flow_invitation.expires_at_local,
      language: @cbv_flow_invitation.language,
      agency_partner_metadata: metadata_contract.permitted
    }

    if @activity_flow_invitation
      response_body[:activity_tokenized_url] = @activity_flow_invitation.to_url
    end

    render json: response_body, status: :created
  end

  def render_validation_errors(record = @cbv_flow_invitation)
    render json: errors_to_json(record.errors),
      status: :unprocessable_content
  end
end

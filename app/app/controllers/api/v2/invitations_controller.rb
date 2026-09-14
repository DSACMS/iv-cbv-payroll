class Api::V2::InvitationsController < Api::InvitationsController
  def create
    unless invitation_type == "income"
      return render json: { error: "Invalid invitation type" }, status: :bad_request
    end

    # Validate that the required doc_id or individual_id is present for LA LDH invitations,
    # Keeping this out of la_ldh.rb for now so that it does not affect v1 invitations_controller.rb
    # not requiring doc_id. Once v1 is deprecated, this can be moved to la_ldh.rb and the v1 controller can be removed.
    if @current_user.client_agency_id.to_s == "la_ldh"
      metadata_params.delete("doc_id") if metadata_params[:doc_id]
      individual_id = metadata_params[:individual_id].presence

      if individual_id.blank?
        return render json: {
          errors: [
            {
              field: "agency_partner_metadata.individual_id",
              message: I18n.t("cbv.applicant_informations.la_ldh.fields.individual_id.blank")
            }
          ]
        }, status: :unprocessable_content
      end
    end

    cbv_invitation_service = CbvInvitationService.new(event_logger)
    @cbv_flow_invitation = cbv_invitation_service
      .invite(cbv_flow_invitation_params, @current_user, delivery_method: nil)

    errors = @cbv_flow_invitation.errors
    if errors.any?
      return render json: errors_to_json(errors), status: :unprocessable_content
    end

    response_body = {
      tokenized_url: @cbv_flow_invitation.to_url,
      expiration_date: @cbv_flow_invitation.expires_at_local,
      language: @cbv_flow_invitation.language,
      agency_partner_metadata: allowed_metadata_params
    }

    if @activity_flow_invitation
      response_body[:activity_tokenized_url] = @activity_flow_invitation.to_url
    end

    render json: response_body, status: :created
  end

  private

  def allowed_metadata_params
    valid_attributes = CbvApplicant
      .valid_attributes_for_agency(@current_user.client_agency_id)
      .map(&:to_s)

    filtered = metadata_params
      .to_h
      .stringify_keys
      .slice(*valid_attributes)

    ActionController::Parameters.new(filtered).permit!
  end

  def metadata_params
    params
      .fetch(:agency_partner_metadata, {})
      .permit(:doc_id, :individual_id, :case_number, :date_of_birth)
  end

  def invitation_type
    params[:type].to_s
  end
end

class Cbv::ApplicantInformationsController < Cbv::BaseController
  before_action :set_cbv_applicant, only: %i[show update]
  before_action :redirect_when_in_invitation_flow, :redirect_when_info_present, only: :show

  def show
    track_applicant_information_access_event
  end

  def update
    @cbv_applicant.assign_attributes(applicant_params[:cbv_applicant])

    if  @cbv_applicant.validate_base_and_applicant_attributes? && @cbv_applicant.save
      return redirect_to next_path
    end

    error_header = t(".error_header", count: @cbv_applicant.errors.count)

    # Use @cbv_applicant.errors directly since we added all errors back to it
    error_messages = @cbv_applicant.errors.map { |error| "<li>#{error.message}</li>" }.join
    error_messages = "<ul>#{error_messages}</ul>"

    flash.now[:alert_heading] = error_header
    flash.now[:alert] = error_messages.html_safe

    track_applicant_information_error_event(error_messages.html_safe)

    render :show, status: :unprocessable_entity

    # note: if we TRULY want that rescue behavior, keep it here. i still think this was a legacy of the save! hack, but it can go here
  rescue Exception => e
    Rails.logger.error("Error updating applicant: #{e.message}")
    flash[:alert] = t(".error_updating_applicant")
    redirect_to cbv_flow_applicant_information_path
  end

  def redirect_when_info_present
    return if params[:force_show] == "true"

    redirect_to next_path unless @cbv_applicant.has_applicant_attribute_missing?
  end

  def redirect_when_in_invitation_flow
    redirect_to next_path if @cbv_flow.cbv_flow_invitation.present?
  end

  def applicant_params
    params.fetch("cbv_applicant_#{@cbv_flow.client_agency_id}", {}).permit(
      cbv_applicant: @cbv_applicant.applicant_attributes
    )
  end

  def set_cbv_applicant
    @cbv_applicant = @cbv_flow.cbv_applicant
  end

  def track_applicant_information_access_event
    if params[:force_show] == "true"
      event_logger.track("ApplicantClickedEditInformationLink", request, {
        timestamp: Time.now.to_i,
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        client_agency_id: current_agency&.id,
        cbv_flow_id: @cbv_flow.id
      })
    else
      event_logger.track("ApplicantAccessedInformationPage", request, {
        timestamp: Time.now.to_i,
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        client_agency_id: current_agency&.id,
        cbv_flow_id: @cbv_flow.id
      })
    end
  rescue => ex
    Rails.logger.error "Unable to track event on ApplicantInformation page #{ex}"
  end

  def track_applicant_information_error_event(error_string)
    event_logger.track("ApplicantEncounteredInformationPageError", request, {
      timestamp: Time.now.to_i,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      client_agency_id: current_agency&.id,
      error_string: error_string
    })
  rescue => ex
    Rails.logger.error "Unable to track event (ApplicantEncounteredInformationPageError): #{ex}"
  end
end

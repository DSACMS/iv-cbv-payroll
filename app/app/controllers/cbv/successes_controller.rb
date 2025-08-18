class Cbv::SuccessesController < Cbv::BaseController
  before_action :track_accessed_success_event, only: :show
  skip_before_action :ensure_cbv_flow_not_yet_complete

  def show
    @invitation_link = invitation_link
  end

  private

  def invitation_link
    if @cbv_flow.cbv_flow_invitation.present?
      @cbv_flow.cbv_flow_invitation.to_url
    else
      @cbv_flow.to_generic_url
    end
  end

  def track_accessed_success_event
    track_event("ApplicantAccessedSuccessPage")
  end

  def track_event(event_name)
    event_logger.track(event_name, request, {
      timestamp: Time.now.to_i,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      client_agency_id: current_agency&.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      origin: session[:cbv_origin]
    })
  rescue => ex
    Rails.logger.error "Failed to track event: #{ex.message}"
  end
end

class Cbv::SuccessesController < Cbv::BaseController
  before_action :track_accessed_success_event, only: :show
  skip_before_action :ensure_cbv_flow_not_yet_complete

  def show
    @invitation_link = invitation_link
  end

  private

  def invitation_link
    host = Rails.env.production? ? current_agency.agency_production_domain : current_agency.agency_demo_domain

    if @cbv_flow.cbv_flow_invitation.present?
      @cbv_flow.cbv_flow_invitation.to_url(host: host, protocol: "https")
    else # generate a generic link
      "https://#{host}/en/cbv/links/#{@cbv_flow.client_agency_id}"
    end
  end

  def track_accessed_success_event
    event_logger.track("ApplicantAccessedSuccessPage", request, {
      timestamp: Time.now.to_i,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      client_agency_id: current_agency&.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  rescue => ex
    Rails.logger.error "Failed to track NewRelic event: #{ex.message}"
  end
end

class Cbv::SuccessesController < Cbv::BaseController
  before_action :track_accessed_success_event, only: :show
  skip_before_action :ensure_cbv_flow_not_yet_complete
  skip_before_action :track_accessed_success_event, only: :check_code

  def show
  end

  def check_code
    @cbv_flow.reload

    render turbo_stream: turbo_stream.replace(
      "confirmation_code",
      partial: "confirmation_code",
      locals: { cbv_flow: @cbv_flow }
    )
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

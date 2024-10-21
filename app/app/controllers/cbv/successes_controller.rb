class Cbv::SuccessesController < Cbv::BaseController
  before_action :track_accessed_success_event, only: :show
  skip_before_action :ensure_cbv_flow_not_yet_complete

  def show
  end

  def track_accessed_success_event
    NewRelicEventTracker.track("ApplicantAccessedSuccessPage", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      has_pinwheel_account: @has_pinwheel_account
    })
  rescue => ex
    Rails.logger.error "Failed to track NewRelic event: #{ex.message}"
  end
end

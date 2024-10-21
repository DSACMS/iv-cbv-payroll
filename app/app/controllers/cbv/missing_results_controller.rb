class Cbv::MissingResultsController < Cbv::BaseController
  before_action :track_missing_results_event, only: :show

  def show
    @has_pinwheel_account = @cbv_flow.pinwheel_accounts.any?
  end

  def track_missing_results_event
    NewRelicEventTracker.track("ApplicantAccessedMissingResultsPage", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      has_pinwheel_account: @has_pinwheel_account
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantAccessedMissingResultsPage): #{ex}"
  end
end

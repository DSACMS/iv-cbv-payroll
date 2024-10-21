class Cbv::ExpiredInvitationsController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :ensure_cbv_flow_not_yet_complete
  helper_method :current_site

  def show
  end

  private

  def current_site
    return unless Rails.application.config.sites.site_ids.include?(params[:site_id])

    Rails.application.config.sites[params[:site_id]]
  end

  def track_expired_event
    NewRelicEventTracker.track("ApplicantLinkExpired", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      has_pinwheel_account: @has_pinwheel_account
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantLinkExpired): #{ex}"
  end
end

class Cbv::ExpiredInvitationsController < Cbv::BaseController
  before_action :track_expired_event, only: :show
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
      timestamp: Time.now.to_i
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantLinkExpired): #{ex}"
  end
end

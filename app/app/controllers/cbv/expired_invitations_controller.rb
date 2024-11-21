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
end

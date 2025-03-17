class Cbv::ExpiredInvitationsController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :ensure_cbv_flow_not_yet_complete, :capture_page_view
  helper_method :current_agency

  def show
  end

  private

  def current_agency
    return unless Rails.application.config.client_agencies.client_agency_ids.include?(params[:client_agency_id])

    Rails.application.config.client_agencies[params[:client_agency_id]]
  end
end

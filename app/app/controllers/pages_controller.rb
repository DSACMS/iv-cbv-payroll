class PagesController < ApplicationController
  before_action :redirect_to_client_agency_entries, only: %i[home]
  helper_method :activity_flow_timeout?

  def home
    return unless flow_timeout?

    # i18n-tasks-use t("pages.home.activity_flow_timeout.alert_html")
    message_key = activity_flow_timeout? ? "pages.home.activity_flow_timeout.alert_html" : "cbv.error_missing_token_html"
    flash.now[:slim_alert] = { "type" => "info", "message_html" => t(message_key) }
  end

  def error_404
    # When in development environment, you'll need to set
    #   config.consider_all_requests_local = false
    # in config/development.rb for these pages to actually show up.
    @flow = flow_class.find_by(id: session[:flow_id])
    @invitation = @flow&.is_a?(ActivityFlow) ? @flow&.activity_flow_invitation : @flow&.cbv_flow_invitation

    render status: :not_found, formats: %i[html]
  end

  def error_500
    # When in development environment, you'll need to set
    #   config.consider_all_requests_local = false
    # in config/development.rb for these pages to actually show up.

    render status: :internal_server_error, formats: %i[html]
  end

  private

  def activity_flow?
    activity_flow_timeout? || super
  end

  def activity_flow_timeout?
    params[:activity_flow_timeout].present?
  end

  def flow_timeout?
    params[:cbv_flow_timeout].present? || activity_flow_timeout?
  end

  def redirect_to_client_agency_entries
    # Don't redirect to CBV flow if the pilot has ended - let the home page render the pilot end message
    return if pilot_ended?

    # Don't redirect if we just came from a flow timeout
    return if flow_timeout?

    client_agency_id = client_agency_from_domain
    if client_agency_id.present?
      agency = agency_config[client_agency_id]

      # Don't redirect agencies that have disabled generic links
      return if agency&.generic_links_disabled

      session[:cbv_origin] = params[:origin] || agency&.default_origin
      redirect_to cbv_flow_new_path(client_agency_id: client_agency_id)
    end
  end
end

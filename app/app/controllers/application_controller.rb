class ApplicationController < ActionController::Base
  helper :view
  helper_method :current_site
  around_action :switch_locale
  before_action :add_newrelic_metadata
  before_action :redirect_if_maintenance_mode

  rescue_from ActionController::InvalidAuthenticityToken do
    redirect_to root_url, flash: { slim_alert: { type: "info", message_html:  t("cbv.error_missing_token_html") } }
  end

  def after_sign_in_path_for(user)
    caseworker_dashboard_path(site_id: user.site_id)
  end

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path(site_id: params[:site_id])
  end

  def switch_locale(&action)
    locale = get_locale(request)
    I18n.with_locale(locale, &action)
    session[:locale] = locale
  end

  def site_config
    Rails.application.config.sites
  end

  private

  def get_locale(request)
    locale_sources = [
      params[:locale],
      request.path.split("/")[1],
      URI(request.env["HTTP_REFERER"]).path.split("/")[1],
      request.env["HTTP_ACCEPT_LANGUAGE"]&.scan(/^[a-z]{2}/)&.first,
      I18n.default_locale
    ]

    locale_sources.compact.find { |locale| I18n.available_locales.map(&:to_s).include?(locale) }
  end

  def current_site
    @current_site ||= site_config[params[:site_id]]
  end

  protected

  def pinwheel_for(cbv_flow)
    environment = site_config[cbv_flow.site_id].pinwheel_environment

    PinwheelService.new(environment)
  end

  def add_newrelic_metadata
    newrelic_params = params.slice(:site_id, :locale).permit

    attributes = {
      cbv_flow_id: session[:cbv_flow_id],
      session_id: session.id.to_s,
      site_id: newrelic_params[:site_id],
      locale: newrelic_params[:locale],
      user_id: current_user.try(:id)
    }

    NewRelic::Agent.add_custom_attributes(attributes)
  end

  def redirect_if_maintenance_mode
    if ENV["MAINTENANCE_MODE"] == "true"
      redirect_to maintenance_path
    end
  end
end

class ApplicationController < ActionController::Base
  helper :view
  helper_method :current_site, :show_translate_button?, :show_menu?
  around_action :switch_locale
  before_action :add_newrelic_metadata
  before_action :redirect_if_maintenance_mode
  before_action :enable_mini_profiler_in_demo
  before_action :check_help_param

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
    requested_locale = params[:locale]
    locale = CbvFlowInvitation::VALID_LOCALES.include?(requested_locale) ? requested_locale : I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def site_config
    Rails.application.config.sites
  end

  private

  def show_translate_button?
    false
  end

  def show_menu?
    # show the menu if we're in the cbv flow
    return true if controller_path.start_with?("cbv/")
    user_signed_in? && !home_page?
  end

  def home_page?
    request.path == root_path
  end

  def current_site
    @current_site ||= site_config[params[:site_id]]
  end

  def enable_mini_profiler_in_demo
    return unless demo_mode?

    Rack::MiniProfiler.authorize_request
  end

  def demo_mode?
    ENV["DOMAIN_NAME"] == "verify-demo.navapbc.cloud"
  end

  protected

  def pinwheel_for(cbv_flow)
    environment = site_config[cbv_flow.site_id].pinwheel_environment

    PinwheelService.new(environment)
  end

  def add_newrelic_metadata
    attributes = {
      cbv_flow_id: session[:cbv_flow_id],
      session_id: session.id.to_s,
      site_id: params[:site_id],
      locale: params[:locale],
      user_id: current_user.try(:id)
    }

    NewRelic::Agent.add_custom_attributes(attributes)
  end

  def event_logger
    @event_logger ||= GenericEventTracker.for_request(request)
  end

  def redirect_if_maintenance_mode
    if ENV["MAINTENANCE_MODE"] == "true"
      redirect_to maintenance_path
    end
  end

  def check_help_param
    if params[:help] == "true"
      help_link = helpers.render(partial: "help/help_link", locals: { text: t("help.alert.help_options"), source: "banner" })
      flash.merge!(
        alert: "#{t('help.alert.text_before')} #{help_link}",
        alert_heading: t("help.alert.heading"),
        alert_type: "warning"
      )
    end
  end
end

class ApplicationController < ActionController::Base
  helper :view
  helper_method :current_agency, :show_translate_button?, :show_menu?
  around_action :switch_locale
  before_action :add_newrelic_metadata
  before_action :redirect_if_maintenance_mode
  before_action :redirect_to_client_agency_entries
  before_action :enable_mini_profiler_in_demo
  before_action :check_help_param

  rescue_from ActionController::InvalidAuthenticityToken do
    redirect_to root_url, flash: { slim_alert: { type: "info", message_html:  t("cbv.error_missing_token_html") } }
  end

  def after_sign_in_path_for(user)
    caseworker_dashboard_path(client_agency_id: user.client_agency_id)
  end

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path(client_agency_id: params[:client_agency_id])
  end

  def switch_locale(&action)
    requested_locale = params[:locale]
    locale = CbvFlowInvitation::VALID_LOCALES.include?(requested_locale) ? requested_locale : I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def agency_config
    Rails.application.config.client_agencies
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

  def current_agency
    # First try to get the agency from the client_agency_id parameter
    return @current_agency if @current_agency.present?

    if params[:client_agency_id].present?
      @current_agency = agency_config[params[:client_agency_id]]
      return @current_agency if @current_agency.present?
    end

    # If not found from params, try to detect from domain
    client_agency_id_from_domain = detect_client_agency_from_domain
    if client_agency_id_from_domain.present?
      @current_agency = agency_config[client_agency_id_from_domain]
    end

    @current_agency
  end

  def enable_mini_profiler_in_demo
    return unless demo_mode?

    Rack::MiniProfiler.authorize_request
  end

  def demo_mode?
    ENV["DOMAIN_NAME"] == "verify-demo.navapbc.cloud"
  end

  def detect_client_agency_from_domain
    return nil unless request.host.present?

    agency_config.client_agency_ids.find do |agency_id|
      agency = agency_config[agency_id]
      [ agency.agency_demo_domain, agency.agency_production_domain ].compact.include?(request.host)
    end
  end

  protected

  def pinwheel_for(cbv_flow)
    environment = agency_config[cbv_flow.client_agency_id].pinwheel_environment

    Aggregators::Sdk::PinwheelService.new(environment)
  end

  def argyle_for(cbv_flow)
    environment = agency_config[cbv_flow.client_agency_id].argyle_environment
    Aggregators::Sdk::ArgyleService.new(environment)
  end

  def add_newrelic_metadata
    attributes = {
      cbv_flow_id: session[:cbv_flow_id],
      session_id: session.id.to_s,
      client_agency_id: params[:client_agency_id],
      locale: params[:locale],
      user_id: current_user.try(:id)
    }

    NewRelic::Agent.add_custom_attributes(attributes)
  end

  def event_logger
    @event_logger ||= GenericEventTracker.new
  end

  def redirect_if_maintenance_mode
    if ENV["MAINTENANCE_MODE"] == "true"
      redirect_to maintenance_path
    end
  end

  def redirect_to_client_agency_entries
    client_agency_id = detect_client_agency_from_domain
    if client_agency_id.present?
      redirect_to cbv_flow_new_path(client_agency_id: client_agency_id)
    end
  end

  def check_help_param
    if params[:help] == "true"
      help_link = helpers.render(partial: "help/help_link", locals: { text: t("help.alert.help_options"), source: "banner" })
      flash.now[:alert] = "#{t('help.alert.text_before')} #{help_link}"
      flash.now[:alert_heading] = t("help.alert.heading")
      flash.now[:alert_type] = "warning"
    end
  end
end

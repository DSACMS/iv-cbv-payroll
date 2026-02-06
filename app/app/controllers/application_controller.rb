class ApplicationController < ActionController::Base
  helper :view
  helper_method :current_agency, :show_menu?, :pilot_ended?, :get_site_alert_title, :get_site_alert_body, :session_timeout_enabled?
  around_action :switch_locale
  before_action :add_newrelic_metadata
  before_action :redirect_if_maintenance_mode
  before_action :enable_mini_profiler_in_demo
  before_action :set_device_id_cookie

  rescue_from ActionController::InvalidAuthenticityToken do
    redirect_to root_url, flash: { slim_alert: { type: "info", message_html: t("cbv.error_missing_token_html") } }
  end

  def after_sign_out_path_for
    new_user_session_path(client_agency_id: params[:client_agency_id])
  end

  def switch_locale(&action)
    locale = determine_locale
    session[:locale] = locale
    I18n.with_locale(locale, &action)
  end

  def agency_config
    Rails.application.config.client_agencies
  end

  private

  def set_device_id_cookie
    cookies.permanent.signed[:device_id] ||= {
      value: SecureRandom.uuid,
      httponly: true
    }
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
    return @current_agency if @current_agency.present?

    @flow = @cbv_flow # Maintain for compatibility until all controllers are converted
    if @flow.present? && @flow.cbv_applicant.client_agency_id.present?
      @current_agency = agency_config[@flow.cbv_applicant.client_agency_id]
      return @current_agency
    end

    if params[:client_agency_id].present?
      @current_agency = agency_config[params[:client_agency_id]]
      return @current_agency
    end

    if client_agency_from_domain.present?
      @current_agency = agency_config[client_agency_from_domain]
    end

    @current_agency
  end

  def session_timeout_enabled?
    session[:flow_id].present?
  end

  def enable_mini_profiler_in_demo
    return unless Rails.application.config.demo_mode

    Rack::MiniProfiler.authorize_request
  end

  def client_agency_from_domain
    return nil unless request.host.present?

    agency_config.client_agency_ids.find do |agency_id|
      agency = agency_config[agency_id]
      agency.agency_domain == request.host
    end
  end

  def pilot_ended?
    @pilot_ended.nil? ? current_agency&.pilot_ended : @pilot_ended
  end

  def reset_cbv_session!
    set_flow_session(nil, nil)
  end

  def set_flow_session(flow_id, type)
    session[:flow_id] = flow_id
    session[:flow_type] = type
  end

  def flow_class(flow_type = session[:flow_type])
    flow_type&.to_sym == :activity ? ActivityFlow : CbvFlow
  end

  protected

  def pinwheel_for(cbv_flow)
    environment = agency_config[cbv_flow.cbv_applicant.client_agency_id].pinwheel_environment

    Aggregators::Sdk::PinwheelService.new(environment)
  end

  def argyle_for(cbv_flow)
    environment = agency_config[cbv_flow.cbv_applicant.client_agency_id].argyle_environment
    Aggregators::Sdk::ArgyleService.new(environment)
  end

  def add_newrelic_metadata
    attributes = {
      cbv_flow_id: session[:flow_id],
      device_id: cookies.permanent.signed[:device_id],
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

  def get_site_alert_title
    case I18n.locale
    when :en
      ENV["SITE_ALERT_TITLE_EN"]
    when :es
      ENV["SITE_ALERT_TITLE_ES"]
    end
  end

  def get_site_alert_body
    case I18n.locale
    when :en
      ENV["SITE_ALERT_BODY_EN"]
    when :es
      ENV["SITE_ALERT_BODY_ES"]
    end
  end

  private

  def determine_locale
    requested_locale = params[:locale]
    if CbvFlowInvitation::VALID_LOCALES.include?(requested_locale)
      requested_locale
    elsif CbvFlowInvitation::VALID_LOCALES.include?(session[:locale])
      session[:locale]
    else
      I18n.default_locale
    end
  end
end

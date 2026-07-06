class ApplicationController < ActionController::Base
  ALPHANUMERIC_PREFIX_REGEXP = /^([a-zA-Z0-9]+)[^a-zA-Z0-9]*$/

  helper :view
  helper_method :current_agency, :show_menu?, :pilot_ended?, :get_site_alert_title, :get_site_alert_body, :activity_flow?, :session_timeout_enabled?, :session_timeout_duration, :internal_environment?
  around_action :switch_locale
  before_action :add_newrelic_metadata, :redirect_if_maintenance_mode, :enable_mini_profiler_in_demo, :set_device_id_cookie
  after_action :apply_iframe_embedding

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
      httponly: true,
      **iframe_cookie_options
    }
  end

  # True when the current agency is configured to permit iframe embedding.
  def iframe_embedding_allowed?
    current_agency&.allowed_iframe_ancestors.present?
  end

  # Cross-origin iframes only send cookies marked `SameSite=None; Secure`.
  # Scope this relaxation to agencies that opt in to embedding so other
  # agencies keep the stricter `SameSite=Lax` default. `Secure` requires HTTPS,
  # so only relax over SSL; otherwise the browser drops the cookie and the
  # session is lost (e.g. E2E/dev served over plain HTTP).
  def iframe_cookie_options
    return {} unless iframe_embedding_allowed? && request.ssl?

    { same_site: :none, secure: true }
  end

  # Relax framing policy and cookies for embedding agencies. Done in an
  # after_action because the agency may only be resolvable once the controller
  # has loaded the flow (e.g. the tokenized `/start/:token` entry, where
  # `current_agency` is still nil during the before_actions). The session and
  # device-id cookies are committed by middleware *after* this runs, so setting
  # `session_options` and re-issuing the device-id cookie here still takes
  # effect on the emitted `Set-Cookie` headers.
  def apply_iframe_embedding
    return if current_agency&.allowed_iframe_ancestors.blank?

    # Reissue the session and device-id cookies as `SameSite=None; Secure` so
    # they survive inside a cross-origin iframe (no-op off SSL).
    if (cookie_options = iframe_cookie_options).present?
      cookie_options.each { |key, value| request.session_options[key] = value }
      if (device_id = cookies.permanent.signed[:device_id]).present?
        cookies.permanent.signed[:device_id] = { value: device_id, httponly: true, **cookie_options }
      end
    end

    if (policy = request.content_security_policy)
      request.content_security_policy = policy.clone.tap do |cloned|
        cloned.frame_ancestors(:self, *current_agency.allowed_iframe_ancestors)
      end
    end
    response.headers.delete("X-Frame-Options")
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

    # Don't memoize the domain fallback: it may be resolved during an early
    # before_action (e.g. iframe/device-id setup) before @cbv_flow is set, and
    # memoizing here would prevent current_agency from later resolving to the
    # flow's agency.
    if client_agency_from_domain.present?
      return agency_config[client_agency_from_domain]
    end

    nil
  end

  def session_timeout_enabled?
    session[:flow_id].present?
  end

  def session_timeout_duration
    (session[:demo_timeout] if internal_environment?) || Rails.application.config.cbv_session_expires_after
  end

  def internal_environment?
    Rails.application.config.is_internal_environment
  end

  def activity_hub_enabled?
    Rails.env.development? || ENV["ACTIVITY_HUB_ENABLED"] == "true"
  end

  def redirect_unless_activity_hub_enabled
    return if activity_hub_enabled?

    redirect_to root_url
  end

  def normalize_token(token)
    ALPHANUMERIC_PREFIX_REGEXP.match(token.to_s)&.[](1)
  end

  def enable_mini_profiler_in_demo
    return unless Rails.application.config.is_internal_environment

    Rack::MiniProfiler.authorize_request
  end

  def client_agency_from_domain
    return @client_agency_from_domain if defined?(@client_agency_from_domain)

    @client_agency_from_domain =
      if request.host.present?
        agency_config.client_agency_ids.find do |agency_id|
          agency_config[agency_id].agency_domain == request.host
        end
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

  def activity_flow?
    flow_class == ActivityFlow
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
      flow_id: session[:flow_id],
      flow_type: flow_class.name,
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

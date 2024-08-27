class ApplicationController < ActionController::Base
  helper :view
  helper_method :current_site
  around_action :switch_locale

  rescue_from ActionController::InvalidAuthenticityToken do
    redirect_to root_url, notice: t("cbv.error_missing_token_html")
  end

  def after_sign_in_path_for(user)
    caseworker_dashboard_path(site_id: user.site_id)
  end

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path(site_id: params[:site_id])
  end

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def site_config
    Rails.application.config.sites
  end

  private

  def current_site
    @current_site ||= site_config[params[:site_id]]
  end

  protected

  def pinwheel_for(cbv_flow)
    api_key = site_config[cbv_flow.site_id].pinwheel_api_token
    environment = site_config[cbv_flow.site_id].pinwheel_environment

    PinwheelService.new(api_key, environment)
  end
end

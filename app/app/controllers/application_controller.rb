class ApplicationController < ActionController::Base
  helper :view
  around_action :switch_locale

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def site_config
    Rails.application.config.sites
  end

  def pinwheel_for(cbv_flow)
    api_key = site_config[cbv_flow.site_id].pinwheel_api_token

    PinwheelService.new(api_key)
  end
end

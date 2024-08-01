class ApplicationController < ActionController::Base
  helper :view
  around_action :switch_locale

  def new_session_path
    new_user_session_path
  end

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def site_config
    Rails.application.config.sites
  end
end

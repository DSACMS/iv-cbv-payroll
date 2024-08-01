class ApplicationController < ActionController::Base
  helper :view
  around_action :switch_locale

  def after_sign_in_path_for(resource)
    invitations_url(site_id: resource.site_id)
  end

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def site_config
    Rails.application.config.sites
  end
end

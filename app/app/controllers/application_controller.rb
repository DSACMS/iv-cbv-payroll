class ApplicationController < ActionController::Base
  helper :view
  around_action :switch_locale

  def after_sign_in_path_for(user)
    invitations_new_url(user.site_id)
  end

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def site_config
    Rails.application.config.sites
  end

  protected

  def authenticate_user!
    if user_signed_in?
      super
    else
      redirect_to sso_path, notice: "Please sign in"
    end
  end
end

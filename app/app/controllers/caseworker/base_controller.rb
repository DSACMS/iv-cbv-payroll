class Caseworker::BaseController < ApplicationController
  before_action :redirect_if_disabled

  def authenticate_user!
    super

    unless current_user.site_id == params[:site_id]
      redirect_to root_url, flash: {
        slim_alert: { message: t("shared.error_unauthorized"), type: "error" }
      }
    end
  end

  def redirect_if_disabled
    unless current_site.staff_portal_enabled
      redirect_to root_url, flash: {
        slim_alert: { message: I18n.t("caseworker.entries.disabled"), type: "error" }
      }
    end
  end
end

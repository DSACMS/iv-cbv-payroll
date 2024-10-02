class Caseworker::BaseController < ApplicationController
  def authenticate_user!
    super

    unless current_user.site_id == params[:site_id]
      redirect_to root_url, flash: {
        slim_alert: { message: t("shared.error_unauthorized"), type: "error" }
      }
    end
  end
end

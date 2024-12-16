class Caseworker::EntriesController < Caseworker::BaseController
  before_action :redirect_if_disabled

  def index
    @current_site = current_site
  end

  def redirect_if_disabled
    unless current_site.staff_portal_enabled
      redirect_to root_url, flash: {
        slim_alert: { message: I18n.t("caseworker.entries.disabled"), type: "error" }
      }
    end
  end
end

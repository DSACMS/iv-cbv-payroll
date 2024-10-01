class Caseworker::BaseController < ApplicationController
  helper_method :language_options

  def authenticate_user!
    super

    unless current_user.site_id == params[:site_id]
      redirect_to root_url, flash: {
        slim_alert: { message: t("shared.error_unauthorized"), type: "error" }
      }
    end
  end

  private

  def language_options
    CbvFlowInvitation::VALID_LANGUAGES.each_with_object({}) do |lang, options|
      options[lang] = I18n.t(".shared.languages.#{lang}", default: lang.to_s.titleize)
    end
  end
end

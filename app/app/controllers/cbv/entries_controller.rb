class Cbv::EntriesController < Cbv::BaseController
  before_action :set_locale
  def show
  end

  def set_locale
    invitation_locale = @cbv_flow&.cbv_flow_invitation&.language&.to_sym

    return if params[:locale] == invitation_locale

    unless request.referer.present?
      I18n.locale = invitation_locale
      redirect_to url_for(locale: invitation_locale, params: request.query_parameters)
    end
  end
end

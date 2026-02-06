class Cbv::GenericLinksController < Cbv::BaseController
  skip_before_action :set_flow, :capture_page_view
  prepend_before_action :set_cbv_origin
  before_action :ensure_valid_client_agency_id
  before_action :check_if_pilot_ended_for_agency
  before_action :redirect_if_generic_links_disabled

  def show
    set_generic_flow
    redirect_to next_path
  end

  private

  def ensure_valid_client_agency_id
    return if agency_config.client_agency_ids.include?(params[:client_agency_id])

    redirect_to root_url, flash: { info: t("cbv.error_invalid_link") }
  end

  def check_if_pilot_ended_for_agency
    agency = agency_config[params[:client_agency_id]]
    if agency&.pilot_ended
      redirect_to root_url
    end
  end

  def redirect_if_generic_links_disabled
    agency = agency_config[params[:client_agency_id]]
    if agency&.generic_links_disabled
      redirect_to root_url
    end
  end
end

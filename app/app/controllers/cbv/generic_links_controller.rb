class Cbv::GenericLinksController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :capture_page_view
  before_action :ensure_valid_client_agency_id
  before_action :check_if_pilot_ended_for_agency

  def show
    @cbv_flow = CbvFlow.create_without_invitation(params[:client_agency_id])
    session[:cbv_flow_id] = @cbv_flow.id
    session[:cbv_source] = params[:source]

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
end

class Cbv::EntriesController < Cbv::BaseController
  def show
    event_logger.track("ApplicantViewedAgreement", request, {
      timestamp: Time.now.to_i,
      client_agency_id: current_agency&.id,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      source: session[:cbv_source]
    })
  end

  def create
    if params["agreement"] == "1"
      event_logger.track("ApplicantAgreed", request, {
        timestamp: Time.now.to_i,
        client_agency_id: current_agency&.id,
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        source: session[:cbv_source]
      })
      redirect_to next_path
    else
      redirect_to(cbv_flow_entry_path, flash: { alert: t(".error") })
    end
  end
end

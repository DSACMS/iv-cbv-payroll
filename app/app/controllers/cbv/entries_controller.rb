class Cbv::EntriesController < Cbv::BaseController
  def show
    @current_agency = current_agency
    
    event_logger.track("ApplicantViewedAgreement", request, {
      timestamp: Time.now.to_i,
      client_agency_id: @cbv_flow.client_agency_id,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  end

  def create
    if params["agreement"] == "1"
      event_logger.track("ApplicantAgreed", request, {
        timestamp: Time.now.to_i,
        client_agency_id: @cbv_flow.client_agency_id,
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id
      })
      redirect_to next_path
    else
      redirect_to(cbv_flow_entry_path, flash: { alert: t(".error") })
    end
  end
end

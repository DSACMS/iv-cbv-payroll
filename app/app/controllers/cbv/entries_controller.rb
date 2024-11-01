class Cbv::EntriesController < Cbv::BaseController
  def show
    NewRelicEventTracker.track("ApplicantViewedAgreement", {
      timestamp: Time.now.to_i,
      site_id: @cbv_flow.site_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  end

  def create
    if params["agreement"] == "1"
      NewRelicEventTracker.track("ApplicantAgreed", {
        timestamp: Time.now.to_i,
        site_id: @cbv_flow.site_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id
      })
      redirect_to next_path
    else
      redirect_to(cbv_flow_entry_path, flash: { alert: t(".error") })
    end
  end
end

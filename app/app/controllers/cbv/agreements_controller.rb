class Cbv::AgreementsController < Cbv::BaseController
  def show
  end

  def create
    if params["agreement"] == "1"
      NewRelicEventTracker.track("ApplicantAgreed", {
        timestamp: Time.now.to_i,
        cbv_flow_id: @cbv_flow.id
      })
      redirect_to next_path
    else
      redirect_to(cbv_flow_agreement_path, flash: { alert: t(".error") })
    end
  end
end

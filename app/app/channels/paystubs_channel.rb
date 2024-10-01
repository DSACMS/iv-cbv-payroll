class PaystubsChannel < ApplicationCable::Channel
  periodically :check_pinwheel_account_synchrony, every: 5.seconds

  def subscribed
    @cbv_flow = CbvFlow.find(connection.session[:cbv_flow_id])
    stream_for @cbv_flow
  end

  private

  def check_pinwheel_account_synchrony
    pinwheel_account = PinwheelAccount.find_by_pinwheel_account_id(params["account_id"])

    if pinwheel_account.present?
      broadcast_to(@cbv_flow, {
        event: "cbv.status_update",
        account_id: pinwheel_account.pinwheel_account_id,
        employment: pinwheel_account.job_completed?("employment"),
        identity: pinwheel_account.job_completed?("identity"),
        paystubs: pinwheel_account.job_completed?("paystubs"),
        income: pinwheel_account.job_completed?("income"),
        has_fully_synced: pinwheel_account.has_fully_synced?
      })
    end
  end
end

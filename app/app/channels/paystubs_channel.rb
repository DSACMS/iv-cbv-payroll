class PaystubsChannel < ApplicationCable::Channel
  periodically :check_pinwheel_account_synchrony, every: 5.seconds

  def subscribed
    @cbv_flow = CbvFlow.find(connection.session[:cbv_flow_id])
    stream_for @cbv_flow
  end

  private

  def check_pinwheel_account_synchrony
    pinwheel_account = PinwheelAccount.find_by_pinwheel_account_id(params["account_id"])

    if pinwheel_account && pinwheel_account.has_fully_synced?
      broadcast_to(@cbv_flow, {
        event: "cbv.payroll_data_available",
        account_id: pinwheel_account.pinwheel_account_id
      })
    end
  end
end

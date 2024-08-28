class Cbv::SynchronizationsController < Cbv::BaseController
  def show
    account_id = params[:user][:account_id]

    @pinwheel_account = PinwheelAccount.find_by_pinwheel_account_id(account_id)

    if @pinwheel_account && @pinwheel_account.has_fully_synced?
      redirect_to cbv_flow_payment_details_path(user: { account_id: @pinwheel_account.pinwheel_account_id })
    end
  end
end

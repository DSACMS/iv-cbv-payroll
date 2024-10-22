class Cbv::SynchronizationsController < Cbv::BaseController
  before_action :set_pinwheel_account, only: %i[show update]

  def show
    handle_redirect
  end

  def update
    handle_redirect
  end

  private

  def handle_redirect
    if @pinwheel_account && @pinwheel_account.has_fully_synced?
      if @pinwheel_account.has_required_data?
        redirect_to cbv_flow_payment_details_path(user: { account_id: @pinwheel_account.pinwheel_account_id })
      else
        redirect_to cbv_flow_synchronization_failures_path
      end
    end
  end

  def set_pinwheel_account
    account_id = params[:user][:account_id]

    @pinwheel_account = @cbv_flow.pinwheel_accounts.find_by(pinwheel_account_id: account_id)
  end
end

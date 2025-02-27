class Cbv::SynchronizationsController < Cbv::BaseController
  before_action :set_pinwheel_account, only: %i[show update]
  before_action :redirect_if_sync_finished, only: %i[show update]

  def show
  end

  def update
  end

  private

  def redirect_if_sync_finished
    if @pinwheel_account.nil?
      return redirect_to cbv_flow_synchronization_failures_path
    end

    if @pinwheel_account.has_fully_synced?
      if @pinwheel_account.has_required_data?
        redirect_to cbv_flow_payment_details_path(user: { account_id: @pinwheel_account.pinwheel_account_id })
      else
        redirect_to cbv_flow_synchronization_failures_path
      end
    end
  end

  def set_pinwheel_account
    account_id = params[:user][:account_id]

    @pinwheel_account = @cbv_flow.payroll_accounts.find_by(pinwheel_account_id: account_id)
  end
end

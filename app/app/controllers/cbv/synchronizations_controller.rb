class Cbv::SynchronizationsController < Cbv::BaseController
  helper_method :job_completed?

  def show
    account_id = params[:user][:account_id]

    @pinwheel_account = @cbv_flow.pinwheel_accounts.find_by(pinwheel_account_id: account_id)

    if @pinwheel_account && @pinwheel_account.has_fully_synced?
      redirect_to cbv_flow_payment_details_path(user: { account_id: @pinwheel_account.pinwheel_account_id })
    end
  end

  private

  def job_completed?(job)
    @pinwheel_account.present? && @pinwheel_account.job_completed?(job)
  end
end

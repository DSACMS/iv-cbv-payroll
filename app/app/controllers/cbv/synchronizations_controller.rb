class Cbv::SynchronizationsController < Cbv::BaseController
  before_action :set_pinwheel_account, only: %i[show update]
  before_action :redirect_if_sync_finished, only: %i[show]
  skip_before_action :capture_page_view, only: %i[update]

  def show
  end

  def update
    if @pinwheel_account.nil?
      render turbo_stream: turbo_stream.action(:redirect, cbv_flow_synchronization_failures_path)
    end

    if @pinwheel_account.has_fully_synced?
      if @pinwheel_account.has_required_data?
        path_to_redirect_to = cbv_flow_payment_details_path(user: { account_id: @pinwheel_account.pinwheel_account_id })
      else
        path_to_redirect_to = cbv_flow_synchronization_failures_path
      end
      render turbo_stream: turbo_stream.action(:redirect, path_to_redirect_to)
    else
      render turbo_stream: turbo_stream.replace(:synchronization, partial: "status")
    end
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

class Cbv::SynchronizationsController < Cbv::BaseController
  before_action :set_payroll_account, only: %i[show update]
  before_action :redirect_if_sync_finished, only: %i[show]
  skip_before_action :capture_page_view, only: %i[update]

  MAX_POLLS = 60 # poll for 2 mins

  def show
    session[:poll_count] = 0
  end

  def update
    if session[:poll_count] >= MAX_POLLS
      render turbo_stream: turbo_stream.action(:redirect, cbv_flow_synchronization_failures_path)
      return
    end

    session[:poll_count] += 1

    if @payroll_account.nil?
      render turbo_stream: turbo_stream.replace(:synchronization, partial: "status")
    elsif @payroll_account.has_fully_synced?
      render turbo_stream: turbo_stream.action(
        :redirect,
        cbv_flow_payment_details_path(user: { account_id: @payroll_account.pinwheel_account_id })
      )
    else
      render turbo_stream: turbo_stream.replace(:synchronization, partial: "status")
    end
  end

  private

  def redirect_if_sync_finished
    if @payroll_account&.has_fully_synced?
      redirect_to cbv_flow_payment_details_path(user: { account_id: @payroll_account.pinwheel_account_id })
    end
  end

  def set_payroll_account
    account_id = params[:user][:account_id]

    @payroll_account = @cbv_flow.payroll_accounts.find_by(pinwheel_account_id: account_id)
  end
end

class Cbv::SynchronizationsController < Cbv::BaseController
  before_action :set_payroll_account, only: %i[show update]
  before_action :redirect_if_session_was_reset, only: %i[update]
  before_action :redirect_if_sync_finished, only: %i[show]
  skip_before_action :capture_page_view, only: %i[update]

  def show
  end

  def update
    if @payroll_account&.job_status("accounts") == :failed
      # argyle throws a "system_error" in the payload of "accounts.updated" webhook.
      # The "accounts" sync status will be set to :failed in that case. The sync status will be :unsupported for pinwheel.
      render turbo_stream: turbo_stream.action(:redirect, cbv_flow_synchronization_failures_path)
    elsif @payroll_account&.has_fully_synced?
      render turbo_stream: turbo_stream.action(
        :redirect,
        cbv_flow_payment_details_path(user: { account_id: @payroll_account.aggregator_account_id })
      )
    else
      render turbo_stream: turbo_stream.replace(:synchronization, partial: "status")
    end
  end

  private

  def set_payroll_account
    account_id = params[:user][:account_id]

    @payroll_account = @cbv_flow.payroll_accounts.find_by(aggregator_account_id: account_id)
  end

  def redirect_if_sync_finished
    if @payroll_account&.has_fully_synced?
      redirect_to cbv_flow_payment_details_path(user: { account_id: @payroll_account.aggregator_account_id })
    end
  end

  # Redirect to /synchronization_failures if the Payroll Account actually
  # exists, but is associated with a different CbvFlow (as would happen if the
  # user started a CbvFlow in a new tab).
  def redirect_if_session_was_reset
    return if @payroll_account.present?

    payroll_account_for_other_flow = PayrollAccount
      .where(aggregator_account_id: params[:user][:account_id])
      .where.not(cbv_flow: @cbv_flow)
    return unless payroll_account_for_other_flow.exists?

    render turbo_stream: turbo_stream.action(:redirect, cbv_flow_synchronization_failures_path)
  end
end

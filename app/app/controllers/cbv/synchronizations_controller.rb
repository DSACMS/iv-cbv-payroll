class Cbv::SynchronizationsController < Cbv::BaseController
  before_action :set_payroll_account, only: %i[show update]
  before_action :redirect_if_session_was_reset, only: %i[update]
  before_action :redirect_if_sync_finished, only: %i[show]
  skip_before_action :capture_page_view, only: %i[update]

  def show
    @polling_url = flow_navigator.income_sync_path(:synchronization, user: { account_id: params[:user][:account_id] })
  end

  def update
    if @payroll_account&.job_status("accounts") == :failed
      # argyle throws a "system_error" in the payload of "accounts.updated" webhook.
      # The "accounts" sync status will be set to :failed in that case. The sync status will be :unsupported for pinwheel.
      render turbo_stream: turbo_stream.action(:redirect, flow_navigator.income_sync_path(:synchronization_failures))
    elsif @payroll_account&.has_fully_synced?
      render turbo_stream: turbo_stream.action(
        :redirect,
        flow_navigator.income_sync_path(:payment_details, user: { account_id: @payroll_account.aggregator_account_id })
      )
    else
      track_polling_wait
      render turbo_stream: turbo_stream.replace(:synchronization, partial: "status")
    end
  end

  private

  def set_payroll_account
    account_id = params[:user][:account_id]

    @payroll_account = @flow.payroll_accounts.find_by(aggregator_account_id: account_id)
  end

  def redirect_if_sync_finished
    if @payroll_account&.has_fully_synced?
      redirect_to flow_navigator.income_sync_path(:payment_details, user: { account_id: @payroll_account.aggregator_account_id })
    end
  end

  # Redirect to /synchronization_failures if the Payroll Account actually
  # exists, but is associated with a different CbvFlow (as would happen if the
  # user started a CbvFlow in a new tab).
  def redirect_if_session_was_reset
    return if @payroll_account.present?

    payroll_account_for_other_flow = PayrollAccount
      .where(aggregator_account_id: params[:user][:account_id])
      .where.not(flow: @flow)
    return unless payroll_account_for_other_flow.exists?

    render turbo_stream: turbo_stream.action(:redirect, flow_navigator.income_sync_path(:synchronization_failures))
  end

  # Track how long users wait on the synchronizations page.
  # Fires every poll (every 2s) while sync is in progress.
  def track_polling_wait
    return unless @payroll_account.present?

    wait_time_seconds = Time.now - @payroll_account.created_at
    provider = @payroll_account.type.demodulize

    NewRelic::Agent.record_custom_event("SyncWaitTime", {
      provider: provider,
      wait_time_seconds: wait_time_seconds
    })
  end
end

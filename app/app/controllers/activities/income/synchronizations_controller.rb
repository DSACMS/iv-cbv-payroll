class Activities::Income::SynchronizationsController < Activities::BaseController
  before_action :set_payroll_account, only: %i[show update]

  before_action :redirect_if_session_was_reset, only: %i[update]
  before_action :redirect_if_sync_finished, only: %i[show]

  def show
    @polling_url = flow_navigator.income_sync_path(:synchronizations, user: { account_id: params[:user][:account_id] })
  end

  def update
    if @payroll_account&.job_status("accounts") == :failed
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

  def session_timeout_enabled?
    false
  end

  def set_payroll_account
    account_id = params[:user][:account_id]

    @payroll_account = @flow.payroll_accounts.find_by(aggregator_account_id: account_id)
  end

  def redirect_if_sync_finished
    if @payroll_account&.has_fully_synced?
      redirect_to flow_navigator.income_sync_path(:payment_details, user: { account_id: @payroll_account.aggregator_account_id })
    end
  end

  def redirect_if_session_was_reset
    return if @payroll_account.present?

    payroll_account_for_other_flow = PayrollAccount
      .where(aggregator_account_id: params[:user][:account_id])
      .where.not(flow: @flow)
    return unless payroll_account_for_other_flow.exists?

    render turbo_stream: turbo_stream.action(:redirect, flow_navigator.income_sync_path(:synchronization_failures))
  end

  def track_polling_wait
    return unless @payroll_account.present?

    wait_time_seconds = Time.now - @payroll_account.created_at
    provider = @payroll_account.type.demodulize

    NewRelic::Agent.record_custom_event("SyncWaitTime", {
      provider: provider,
      flow_id: @payroll_account.flow_id,
      flow_type: @payroll_account.flow_type,
      aggregator_account_id: @payroll_account.aggregator_account_id,
      wait_time_seconds: wait_time_seconds
    })
  end
end

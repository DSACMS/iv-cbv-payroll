class PayrollAccount::Argyle < PayrollAccount
  scope :awaiting_fully_synced_webhook, -> do
    joins(<<~SQL).where(webhook_events: { id: nil })
      LEFT OUTER JOIN webhook_events
      ON webhook_events.payroll_account_id = payroll_accounts.id
      AND webhook_events.event_name = 'users.fully_synced'
    SQL
  end

  def has_fully_synced?
    # Consider the sync finished if every webhook has returned either an error
    # or success. Any webhook with an "unknown" status will not impact the
    # result of this method.
    supported_jobs.all? do |job|
      supported_jobs.exclude?(job) ||
        find_webhook_event_for_job(job, "error").present? ||
        find_webhook_event_for_job(job, "success").present?
    end
  end

  def job_succeeded?(job)
    job_status(job) == :succeeded
  end

  def job_status(job)
    if supported_jobs.exclude?(job)
      :unsupported
    elsif find_webhook_event_for_job(job, "error").present?
      :failed
    elsif find_webhook_event_for_job(job, "success").present?
      :succeeded
    else
      :in_progress
    end
  end

  def necessary_jobs_succeeded?
    job_succeeded?("accounts") && (job_succeeded?("paystubs") || job_succeeded?("gigs"))
  end

  def find_webhook_event_for_job(job, event_outcome = nil)
    webhook_events.find do |webhook_event|
      Aggregators::Webhooks::Argyle::EVENT_NAMES_BY_JOB[job].include?(webhook_event.event_name) &&
        (event_outcome.nil? || webhook_event.event_outcome == event_outcome.to_s)
    end
  end

  def sync_started_at
    # Argyle sends `account.updated` webhook events while the user still has
    # the modal open (as they complete MFA). Since the user may take
    # arbitrarily long to complete MFA, we don't want to count this against the
    # sync time.
    account_connected_at = webhook_events
      .find { |webhook_event| webhook_event.event_name == "accounts.connected" }
      &.created_at

    # If, for some reason, we didn't get the `accounts.connected` event (?),
    # let's at least not crash anything that depends on this method.
    account_connected_at || created_at
  end

  def redact!
    argyle_environment = Rails.application.config.client_agencies[cbv_flow.client_agency_id].argyle_environment
    argyle = Aggregators::Sdk::ArgyleService.new(argyle_environment)
    argyle.delete_account_api(account: aggregator_account_id)
    touch(:redacted_at)
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Unable to redact PayrollAccount::Argyle Account ID #{aggregator_account_id} - #{ex.message}"
    GenericEventTracker.new.track("DataRedactionFailure", nil, { account_id: aggregator_account_id })
  end
end

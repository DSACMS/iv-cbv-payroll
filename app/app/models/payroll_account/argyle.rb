class PayrollAccount::Argyle < PayrollAccount
  scope :awaiting_fully_synced_webhook, -> do
    joins(<<~SQL).where(webhook_events: { id: nil })
      LEFT OUTER JOIN webhook_events
      ON webhook_events.payroll_account_id = payroll_accounts.id
      AND webhook_events.event_name = 'users.fully_synced'
    SQL
  end

  def has_fully_synced?
    supported_jobs.all? do |job|
      supported_jobs.exclude?(job) || find_webhook_event_for_job(job).present?
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
end

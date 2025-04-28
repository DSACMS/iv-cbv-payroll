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
      supported_jobs.exclude?(job) || find_webhook_event(self.class.event_for_job(job)).present?
    end
  end

  def job_succeeded?(job)
    job_status(job) == :succeeded
  end

  def accounts_job_status
    # the argyle accounts.updated event requires special handling because it's outcome is dynamic based on its payload.
    if find_webhook_event("accounts.updated", "error").present?
      :failed
    else
      :succeeded
    end
  end

  def job_status(job)
    if supported_jobs.exclude?(job)
      :unsupported
    elsif job == "accounts"
      accounts_job_status
    elsif find_webhook_event(self.class.event_for_job(job), "success").present?
      :succeeded
    elsif find_webhook_event(self.class.event_for_job(job), "error").present?
      :failed
    else
      :in_progress
    end
  end

  def necessary_jobs_succeeded?
    job_succeeded?("accounts") && (job_succeeded?("paystubs") || job_succeeded?("gigs"))
  end

  def self.event_for_job(job)
    matching_event = Aggregators::Webhooks::Argyle::SUBSCRIBED_WEBHOOK_EVENTS.find do |event_name, config|
      config[:job].include?(job)
    end
    raise "No event for job named: #{job}" unless matching_event.present?

    matching_event.first
  end
end

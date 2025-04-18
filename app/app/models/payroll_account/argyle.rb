class PayrollAccount::Argyle < PayrollAccount
  scope :awaiting_fully_synced_webhook, -> do
    joins(<<~SQL).where(webhook_events: { id: nil })
      LEFT OUTER JOIN webhook_events
      ON webhook_events.payroll_account_id = payroll_accounts.id
      AND webhook_events.event_name = 'users.fully_synced'
    SQL
  end

  # Jobs are used to map real-time Argyle data retrieval with the synchronizations page indicators
  # We can assume that when the paystubs are fully synced, the employment and paystubs are also fully synced
  def has_fully_synced?
    supported_jobs.all? do |job|
      supported_jobs.exclude?(job) || find_webhook_event(self.class.event_for_job(job)).present?
    end
  end

  def successfully_synced?
    supported_jobs.all? do |job|
      job_succeeded?(job)
    end
  end

  def job_succeeded?(job)
    supported_jobs.include?(job) && find_webhook_event(self.class.event_for_job(job), "success").present?
  end

  def synchronization_status(job)
    if supported_jobs.exclude?(job)
      :unsupported
    elsif job_succeeded?(job)
      :succeeded
    elsif find_webhook_event(self.class.event_for_job(job), "success").nil? && find_webhook_event(self.class.event_for_job(job), "error").nil?
      :in_progress
    elsif find_webhook_event(self.class.event_for_job(job), "error").present?
      :failed
    end
  end

  def has_required_data?
    job_succeeded?("paystubs") || job_succeeded?("gigs")
  end

  def self.event_for_job(job)
    matching_event = Aggregators::Webhooks::Argyle::SUBSCRIBED_WEBHOOK_EVENTS.find do |event_name, config|
      config[:job].include?(job)
    end
    raise "No event for job named: #{job}" unless matching_event.present?

    matching_event.first
  end
end

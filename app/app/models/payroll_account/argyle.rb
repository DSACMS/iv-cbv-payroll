class PayrollAccount::Argyle < PayrollAccount
  JOBS_TO_WEBHOOK_EVENTS = {
    "identities" => "identities.added",
    "paystubs" => "paystubs.added",
    "gigs" => "gigs.fully_synced"
  }

  def has_fully_synced?
    supported_jobs.all? do |job|
      supported_jobs.exclude?(job) || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job]).present?
    end
  end

  def job_succeeded?(job)
    supported_jobs.include?(job) && find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], "success").present?
  end

  def synchronization_status(job)
    if supported_jobs.exclude?(job)
      :unsupported
    elsif job_succeeded?(job)
      :succeeded
    elsif find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], "success").nil? && find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], "error").nil?
      :in_progress
    elsif find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], "error").present?
      :failed
    end
  end

  def has_required_data?
    job_succeeded?("paystubs") || job_succeeded?("gigs")
  end

  # Helper method to get supported job types from the hash keys
  def self.available_jobs
    JOBS_TO_WEBHOOK_EVENTS.keys
  end
end

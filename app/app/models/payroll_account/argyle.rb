class PayrollAccount::Argyle < PayrollAccount
  # Jobs are used to map real-time Argyle data retrieval with the synchronizations page indicators
  # We can assume that when the paystubs are fully synced, the employment and paystubs are also fully synced
  def has_fully_synced?
    supported_jobs.all? do |job|
      supported_jobs.exclude?(job) || find_webhook_event(self.class.jobs_to_webhook_events[job]).present?
    end
  end

  def job_succeeded?(job)
    supported_jobs.include?(job) && find_webhook_event(self.class.jobs_to_webhook_events[job], "success").present?
  end

  def synchronization_status(job)
    if supported_jobs.exclude?(job)
      :unsupported
    elsif job_succeeded?(job)
      :succeeded
    elsif find_webhook_event(self.class.jobs_to_webhook_events[job], "success").nil? && find_webhook_event(self.class.jobs_to_webhook_events[job], "error").nil?
      :in_progress
    elsif find_webhook_event(self.class.jobs_to_webhook_events[job], "error").present?
      :failed
    end
  end

  def has_required_data?
    job_succeeded?("paystubs") || job_succeeded?("gigs")
  end

  # Helper method to get supported job types from the hash keys
  def self.available_jobs
    jobs_to_webhook_events.keys
  end

  # Generate jobs to webhook events mapping from ArgyleService
  def self.jobs_to_webhook_events
    Webhooks::Argyle::SUBSCRIBED_WEBHOOK_EVENTS.each_with_object({}) do |(event, details), hash|
      next unless details[:job].is_a?(Array)

      details[:job].each do |job|
        hash[job] = event
      end
    end
  end
end

class PayrollAccount::Pinwheel < PayrollAccount
  JOBS_TO_WEBHOOK_EVENTS = {
    # Mapping of job name (in supported jobs) to the webhook event name that
    # signifies its completion.
    "paystubs" => "paystubs.fully_synced",
    "employment" => "employment.added",
    "income" => "income.added",
    "identity" => "identity.added",
    "gigs" => "gigs.fully_synced"
  }

  def has_fully_synced?
    (supported_jobs.exclude?("paystubs") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["paystubs"]).present?) &&
      (supported_jobs.exclude?("gigs") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["gigs"]).present?) &&
      (supported_jobs.exclude?("employment") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["employment"]).present?) &&
      (supported_jobs.exclude?("income") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["income"]).present?) &&
      (supported_jobs.exclude?("identity") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["identity"]).present?)
  end

  def job_succeeded?(job)
    supported_jobs.include?(job) && find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :success).present?
  end

  def synchronization_status(job)
    if supported_jobs.exclude?(job)
      :unsupported
    elsif job_succeeded?(job)
      :succeeded
    elsif find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :success).nil? && find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :error).nil?
      :in_progress
    elsif find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :error).present?
      :failed
    end
  end

  def has_required_data?
    job_succeeded?("paystubs")
  end
end

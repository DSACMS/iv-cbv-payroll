class PayrollAccount::Pinwheel < PayrollAccount
  JOBS_TO_WEBHOOK_EVENTS = {
    # Mapping of job name (in supported jobs) to the webhook event name that
    # signifies its completion.
    "paystubs" => "paystubs.fully_synced",
    "employment" => "employment.added",
    "income" => "income.added",
    "identity" => "identity.added",
    "shifts" => "shifts.added"
  }

  def has_fully_synced?
    (supported_jobs.exclude?("paystubs") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["paystubs"]).present?) &&
      (supported_jobs.exclude?("shifts") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["shifts"]).present?) &&
      (supported_jobs.exclude?("employment") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["employment"]).present?) &&
      (supported_jobs.exclude?("income") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["income"]).present?) &&
      (supported_jobs.exclude?("identity") || find_webhook_event(JOBS_TO_WEBHOOK_EVENTS["identity"]).present?)
  end

  def job_succeeded?(job)
    job_status(job) == :succeeded
  end

  def job_status(job)
    if supported_jobs.exclude?(job)
      :unsupported
    elsif find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :success).present?
      :succeeded
    elsif find_webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :error).present?
      :failed
    else
      :in_progress
    end
  end

  def necessary_jobs_succeeded?
    job_succeeded?("paystubs")
  end

  def redact!
    # Do nothing, as Pinwheel does not support the deletion of data via API.
    touch(:redacted_at)
  end
end

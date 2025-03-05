class PayrollAccount::Pinwheel < PayrollAccount
  JOBS_TO_WEBHOOK_EVENTS = {
    # Mapping of job name (in supported jobs) to the webhook event name that
    # signifies its completion.
    "paystubs" => "paystubs.fully_synced",
    "employment" => "employment.added",
    "income" => "income.added",
    "identity" => "identity.added"
  }

  def has_fully_synced?
    (supported_jobs.exclude?("paystubs") || webhook_event(JOBS_TO_WEBHOOK_EVENTS["paystubs"]).present?) &&
      (supported_jobs.exclude?("employment") || webhook_event(JOBS_TO_WEBHOOK_EVENTS["employment"]).present?) &&
      (supported_jobs.exclude?("income") || webhook_event(JOBS_TO_WEBHOOK_EVENTS["income"]).present?) &&
      (supported_jobs.exclude?("identity") || webhook_event(JOBS_TO_WEBHOOK_EVENTS["identity"]).present?)
  end

  def job_succeeded?(job)
    supported_jobs.include?(job) && webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :success).present?
  end

  def synchronization_status(job)
    if supported_jobs.exclude?(job)
      :unsupported
    elsif job_succeeded?(job)
      :succeeded
    elsif webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :success).nil? && webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :error).nil?
      :in_progress
    elsif webhook_event(JOBS_TO_WEBHOOK_EVENTS[job], :error).present?
      :failed
    end
  end

  def has_required_data?
    job_succeeded?("paystubs")
  end
end

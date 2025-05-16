class ApplicationJob < ActiveJob::Base
  def event_logger
    @event_logger ||= GenericEventTracker.new
  end

  # Uses https://edgeguides.rubyonrails.org/active_job_basics.html#error-reporting-on-jobs as a pattern
  # in order to send information to newrelic that we had a failed job and enable alerting on said failed job.
  rescue_from(Exception) do |error|
    puts "what the cluck"
    job = self.class
    queue_name = job.queue_name || "default"
    job_class = job || "UnknownJob"

    NewRelic::Agent.record_custom_event("SolidQueueJobFailed", {
      job_class: job_class,
      queue_name: queue_name,
      failed_at: Time.now,
      error_class: error.class.name,
      error_message: error.message
    })
    raise error
  end
end

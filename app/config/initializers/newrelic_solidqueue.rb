require "active_support/notifications"

require "active_support/notifications"

# Subscribe to when a job fails
ActiveSupport::Notifications.subscribe("solid_queue.job_failed") do |name, start, finish, id, payload|
  job = payload[:job]
  error = payload[:error]
  queue_name = job.queue_name || "default"
  job_class = job.job_class || "UnknownJob"

  NewRelic::Agent.record_custom_event("SolidQueueJobFailed", {
    job_class: job_class,
    queue_name: queue_name,
    failed_at: finish,
    error_class: error.class.name,
    error_message: error.message
  })

  puts "sending error result to NewRelic!"

  NewRelic::Agent.record_metric("Custom/SolidQueue/#{job_class}/Failed", 1)
end

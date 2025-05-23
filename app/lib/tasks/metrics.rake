namespace :telemetry do
  desc "Send batched metrics to newrelic on a regular cadence"
  task send_queue_metrics: :environment do
    NewRelic::Agent.record_metric("Custom/SolidQueue/PendingJobs", SolidQueue::ReadyExecution.count)
  end
end

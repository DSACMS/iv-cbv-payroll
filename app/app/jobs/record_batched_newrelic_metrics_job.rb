class RecordBatchedNewrelicMetricsJob < ApplicationJob
  queue_as :default

  def perform
    NewRelic::Agent.record_metric("Custom/SolidQueue/PendingJobs", SolidQueue::ReadyExecution.count)
    NewRelic::Agent.record_metric("Custom/SolidQueue/FailedJobs", SolidQueue::FailedExecution.count)
    NewRelic::Agent.record_metric("Custom/SolidQueue/ClaimedJobs", SolidQueue::ClaimedExecution.count)
  rescue => e
    Rails.logger.warn("Error recording New Relic queue metrics: #{e.message}")
  end
end

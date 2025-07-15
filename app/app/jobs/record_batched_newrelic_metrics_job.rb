class RecordBatchedNewrelicMetricsJob < ApplicationJob
  queue_as :default

  def perform
    NewRelic::Agent.record_metric("Custom/SolidQueue/PendingJobs", SolidQueue::ReadyExecution.count)
  end
end

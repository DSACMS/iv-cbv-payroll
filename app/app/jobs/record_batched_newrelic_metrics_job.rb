class RecordBatchedNewrelicMetricsJob < ApplicationJob
  queue_as :default

  def perform
    NewRelic::Agent.record_metric("Custom/SolidQueue/PendingJobs", SolidQueue::ReadyExecution.count)
    NewRelic::Agent.record_metric("Custom/SolidQueue/FailedJobs", SolidQueue::FailedExecution.count)
    NewRelic::Agent.record_metric("Custom/SolidQueue/ClaimedJobs", SolidQueue::ClaimedExecution.count)

    Aggregators::Sdk::NscCertificateService.new.check_and_alert!
  rescue => e
    Rails.logger.warn("Error checking NSC certificate in RecordBatchedNewrelicMetricsJob: #{e.message}")
  end
end

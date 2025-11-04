class TestQueueingJob < ApplicationJob
  queue_as :report_sender
  def perform(random_id, fail_it = false)
    raise "Failure example" if fail_it
  end
end

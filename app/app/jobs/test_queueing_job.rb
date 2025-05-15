class TestQueueingJob < ApplicationJob
  queue_as :default
  def perform(random_id, fail_it = false)
    raise "Failure example" if fail_it
  end
end

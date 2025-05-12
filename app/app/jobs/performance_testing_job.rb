class PerformanceTestingJob < ApplicationJob
  queue_as :default
  def perform(random_id)
  end
end

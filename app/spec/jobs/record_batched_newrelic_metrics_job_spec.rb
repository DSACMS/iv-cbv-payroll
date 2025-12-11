require "rails_helper"

RSpec.describe RecordBatchedNewrelicMetricsJob do
  class TestJobThatDoesNothing < ApplicationJob
    def perform
      Rails.logger.info "Ran TestJob#perform"
    end
  end

  describe "#perform" do
    before do
      allow(NewRelic::Agent).to receive(:record_metric)
    end

    around do |ex|
      ActiveJob::Base.queue_adapter = :solid_queue
      ex.run
      ActiveJob::Base.queue_adapter = :test
    end

    it "tracks NewRelic metrics" do
      TestJobThatDoesNothing.perform_later

      described_class.perform_now

      expect(NewRelic::Agent).to have_received(:record_metric)
        .with("Custom/SolidQueue/PendingJobs", 1)
      expect(NewRelic::Agent).to have_received(:record_metric)
        .with("Custom/SolidQueue/FailedJobs", 0)
      expect(NewRelic::Agent).to have_received(:record_metric)
        .with("Custom/SolidQueue/ClaimedJobs", 0)
    end
  end
end

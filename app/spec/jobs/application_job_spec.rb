require "rails_helper"

RSpec.describe ApplicationJob do
  class TestJob < ApplicationJob
    def perform
      raise "failed"
    end
  end

  it "records to newrelic" do
    expect(NewRelic::Agent).to receive(:record_custom_event).with("SolidQueueJobFailed", anything)
    expect { TestJob.perform_now }.to raise_error("failed")
  end
end

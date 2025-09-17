require "rails_helper"

RSpec.describe ApplicationJob do
  include ActiveJob::TestHelper

  class TestJob < ApplicationJob
    def perform
      raise "failed"
    end
  end

  it "records to newrelic" do
    allow_any_instance_of(TestJob).to receive(:perform).and_raise(Exception.new)
    expect(NewRelic::Agent).to receive(:record_custom_event).with("SolidQueueJobFailed", anything)
    perform_enqueued_jobs do
      expect { TestJob.perform_now }.to raise_error(Exception)
    end
  end
end

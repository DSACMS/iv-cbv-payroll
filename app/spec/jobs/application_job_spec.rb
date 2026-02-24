require "rails_helper"

RSpec.describe ApplicationJob do
  describe "#with_error_reporting" do
    class TestJob < ApplicationJob
      def perform
        puts "running"
        raise StandardError, "failed"
      end
    end

    it "records to newrelic with job tracking and distributed tracing metadata" do
      expect(NewRelic::Agent).to receive(:record_custom_event).with(
        "SolidQueueJobFailed",
        hash_including(
          executions: 1,
          max_attempts: 5,
          job_id: anything
        )
      )

      TestJob.perform_now
    end

    it "results in the job still remaining enqueued in to retry in the future" do
      expect do
        TestJob.perform_now
      end.to have_enqueued_job(TestJob)
    end
  end

  describe "#with_flow_tags" do
    let(:cbv_applicant) { create(:cbv_applicant, client_agency_id: "sandbox") }
    let(:cbv_flow) { create(:cbv_flow, cbv_applicant: cbv_applicant) }

    class TagTestJob < ApplicationJob
      attr_accessor :logged_message

      def perform(flow)
        with_flow_tags(flow) do
          Rails.logger.info "Test log message"
          @logged_message = "executed"
        end
      end
    end

    context "when STRUCTURED_LOGGING_ENABLED is true" do
      around do |example|
        ClimateControl.modify(STRUCTURED_LOGGING_ENABLED: "true") do
          example.run
        end
      end

      it "wraps the block with tagged logging containing flow attributes" do
        expected_tags = {
          flow_id: cbv_flow.id,
          flow_type: "CbvFlow",
          invitation_id: cbv_flow.invitation_id,
          cbv_applicant_id: cbv_flow.cbv_applicant_id,
          client_agency_id: cbv_flow.cbv_applicant.client_agency_id,
          device_id: cbv_flow.device_id
        }

        expect(Rails.logger).to receive(:tagged).with(expected_tags).and_call_original

        job = TagTestJob.new
        job.perform(cbv_flow)
        expect(job.logged_message).to eq("executed")
      end
    end

    context "when STRUCTURED_LOGGING_ENABLED is false" do
      around do |example|
        ClimateControl.modify(STRUCTURED_LOGGING_ENABLED: "false") do
          example.run
        end
      end

      it "executes the block without tagging" do
        expect(Rails.logger).not_to receive(:tagged)

        job = TagTestJob.new
        job.perform(cbv_flow)
        expect(job.logged_message).to eq("executed")
      end
    end

    context "when STRUCTURED_LOGGING_ENABLED is not set" do
      around do |example|
        ClimateControl.modify(STRUCTURED_LOGGING_ENABLED: nil) do
          example.run
        end
      end

      it "executes the block without tagging" do
        expect(Rails.logger).not_to receive(:tagged)

        job = TagTestJob.new
        job.perform(cbv_flow)
        expect(job.logged_message).to eq("executed")
      end
    end
  end
end

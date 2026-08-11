require "rails_helper"

RSpec.describe ActivityFlowTransmitterJob, type: :job do
  let(:activity_flow) do
    create(
      :activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      completed_at: Time.current,
      confirmation_code: "SANDBOX123"
    )
  end
  let(:transmission_method) { Transmitters::ActivityS3Transmitter::TRANSMISSION_METHOD }
  let(:current_agency) do
    instance_double(
      ClientAgencyConfig::ClientAgency,
      activity_flow_transmission_method: transmission_method,
      applicant_attribute_names: [],
      applicant_attributes: {}
    )
  end
  let(:transmitter) { instance_double(Transmitters::ActivityS3Transmitter) }

  before do
    allow(Rails.application.config.client_agencies).to receive(:[])
      .with(activity_flow.cbv_applicant.client_agency_id)
      .and_return(current_agency)
    allow(Transmitters::ActivityS3Transmitter).to receive(:new)
      .with(activity_flow, current_agency)
      .and_return(transmitter)
  end

  it "marks the flow transmitted after the complete batch succeeds" do
    allow(transmitter).to receive(:deliver)

    expect {
      described_class.new.perform(activity_flow.id)
    }.to change { activity_flow.reload.transmitted_at }.from(nil)
  end

  it "leaves the flow untransmitted when delivery fails" do
    allow(transmitter).to receive(:deliver).and_raise(StandardError, "upload failed")

    expect {
      described_class.new.perform(activity_flow.id)
    }.to raise_error(StandardError, "upload failed")

    expect(activity_flow.reload.transmitted_at).to be_nil
  end

  context "when no activity flow transmitter is configured" do
    let(:transmission_method) { nil }

    it "leaves the flow untransmitted" do
      expect {
        described_class.new.perform(activity_flow.id)
      }.not_to change { activity_flow.reload.transmitted_at }
    end
  end

  context "when the configured transmission method is unsupported" do
    let(:transmission_method) { "sftp" }

    it "raises a configuration error" do
      expect {
        described_class.new.perform(activity_flow.id)
      }.to raise_error("Unsupported activity flow transmission method: sftp")
    end
  end

  context "when the agency uses HTTP document transmission" do
    let(:transmission_method) { Transmitters::HttpDocumentTransmitter::TRANSMISSION_METHOD }
    let(:http_transmitter) { instance_double(Transmitters::HttpDocumentTransmitter) }

    before do
      allow(Transmitters::HttpDocumentTransmitter).to receive(:new)
        .with(activity_flow, current_agency)
        .and_return(http_transmitter)
    end

    it "marks the flow transmitted after document delivery succeeds" do
      allow(http_transmitter).to receive(:deliver)

      expect {
        described_class.new.perform(activity_flow.id)
      }.to change { activity_flow.reload.transmitted_at }.from(nil)
    end

    it "leaves the flow untransmitted when document delivery fails" do
      allow(http_transmitter).to receive(:deliver).and_raise(StandardError, "delivery failed")

      expect {
        described_class.new.perform(activity_flow.id)
      }.to raise_error(StandardError, "delivery failed")

      expect(activity_flow.reload.transmitted_at).to be_nil
    end
  end

  describe "retry behavior" do
    let(:retry_test_time) { Time.zone.parse("2026-08-06 10:00:00") }

    around do |example|
      Timecop.freeze(retry_test_time, &example)
    end

    before do
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      allow(transmitter).to receive(:deliver).and_raise(StandardError, "upload failed")
    end

    it "retries the complete transmission without marking the flow transmitted" do
      expect { described_class.perform_now(activity_flow.id) }
        .to have_enqueued_job(described_class)
        .with(activity_flow.id)
        .at(retry_test_time + 5.minutes)

      expect(activity_flow.reload.transmitted_at).to be_nil
    end
  end
end

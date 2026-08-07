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
  let(:current_agency) do
    instance_double(
      ClientAgencyConfig::ClientAgency,
      activity_flow_transmission_method: Transmitters::ActivityS3Transmitter::TRANSMISSION_METHOD,
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

require "rails_helper"

RSpec.describe NscSynchronizationJob do
  let(:activity_flow) do
    create(:activity_flow, with_identity: true, education_activities_count: 0,
      volunteering_activities_count: 0, job_training_activities_count: 0)
  end
  let(:education_activity) { create(:education_activity, activity_flow: activity_flow, draft: true) }
  let(:job) { described_class.new(education_activity.id) }
  let(:fetcher) { instance_double(NscDataFetcherService) }
  let(:attributes) do
    hash_including(cbv_flow_id: activity_flow.id, cbv_applicant_id: activity_flow.cbv_applicant_id,
      invitation_id: activity_flow.invitation_id, client_agency_id: activity_flow.cbv_applicant.client_agency_id,
      device_id: activity_flow.device_id, flow_type: "ce", education_flow: "nsc",
      education_activity_id: education_activity.id, lookup_attempt: 1, duration_ms: kind_of(Integer))
  end

  before do
    allow(job).to receive(:data_fetcher_service).and_return(fetcher)
    allow(EventTrackingJob).to receive(:perform_later)
  end

  context "with validated enrollment" do
    before do
      allow(fetcher).to receive(:fetch) do
        education_activity.update!(status: :succeeded)
        create(:nsc_enrollment_term, education_activity: education_activity)
      end
    end

    it "tracks the lookup result through the shared tracker without an HTTP request" do
      job.perform_now

      expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationNscLookupCompleted, nil, attributes)
      expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationNscLookupCompleted, nil,
        hash_including(outcome: "validated", term_count: 1, enrollment_status_counts: { "half_time" => 1 },
          months_with_sufficient_enrollment: activity_flow.reporting_months.size))
    end

    it "does not retry a successful lookup when tracking fails" do
      allow(EventTrackingJob).to receive(:perform_later).and_raise(StandardError, "event queue unavailable")

      expect { job.perform_now }.not_to have_enqueued_job(described_class)
      expect(education_activity.reload).to be_sync_succeeded
    end
  end

  context "with partial data" do
    before do
      allow(fetcher).to receive(:fetch) do
        education_activity.update!(status: :succeeded, data_source: :partially_self_attested)
        create(:nsc_enrollment_term, :less_than_half_time, education_activity: education_activity)
      end
    end

    it "identifies partial self-attestation and reports coverage without school or identity data" do
      job.perform_now

      expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationNscLookupCompleted, nil,
        hash_including(outcome: "partial_data", education_data_source: "partially_self_attested", months_with_sufficient_enrollment: 0))
      expect(EventTrackingJob).not_to have_received(:perform_later).with(anything, anything,
        hash_including(school_name: anything))
    end
  end

  context "with no enrollments" do
    before { allow(fetcher).to receive(:fetch) { education_activity.update!(status: :no_enrollments) } }

    it "reports no enrollments rather than a service error" do
      job.perform_now

      expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationNscLookupCompleted, nil,
        hash_including(outcome: "no_enrollments", term_count: 0, months_with_enrollment: 0))
    end
  end

  context "when the lookup raises an error" do
    before { allow(fetcher).to receive(:fetch).and_raise(StandardError, "lookup failed") }

    it "tracks the failed attempt while preserving the existing retry behavior" do
      expect { job.perform_now }.to have_enqueued_job(described_class).with(education_activity.id)
      expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationNscLookupCompleted, nil,
        hash_including(outcome: "service_error", education_data_source: "pending", lookup_attempt: 1))
      expect(education_activity.reload).to be_sync_unknown
    end
  end
end

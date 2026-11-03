require "rails_helper"

RSpec.describe Activities::EducationController, type: :controller do
  include_context "activity_hub"
  render_views

  let(:activity_flow) do
    create(:activity_flow, with_identity: true, education_activities_count: 0,
      volunteering_activities_count: 0, job_training_activities_count: 0)
  end
  let(:education_activity) do
    create(:education_activity, activity_flow: activity_flow, draft: true,
      education_type: "college_or_university", status: :succeeded)
  end
  let(:event_attributes) do
    hash_including(cbv_flow_id: activity_flow.id, cbv_applicant_id: activity_flow.cbv_applicant_id,
      invitation_id: activity_flow.invitation_id, client_agency_id: activity_flow.cbv_applicant.client_agency_id,
      education_activity_id: education_activity.id, education_flow: "nsc", education_data_source: education_activity.data_source)
  end

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
    allow(EventTrackingJob).to receive(:perform_later)
  end

  describe "NSC page views" do
    it "does not classify an unselected education information page as NSC" do
      get :new

      expect(EventTrackingJob).to have_received(:perform_later).with(
        TrackEvent::EducationInfoViewed, anything,
        hash_excluding(:education_flow, :education_data_source, :nsc_status))
    end

    it "does not classify a manual college information page as NSC" do
      get :new, params: { education_type: "college_or_university" }

      expect(EventTrackingJob).to have_received(:perform_later).with(
        TrackEvent::EducationInfoViewed, anything,
        hash_excluding(:education_flow, :education_data_source, :nsc_status))
    end

    it "does not add NSC context to the manual information page when NSC is disabled" do
      stub_environment_variable("NSC_DISABLED", "true") do
        get :new, params: { education_type: "college_or_university" }
      end

      expect(EventTrackingJob).to have_received(:perform_later).with(
        TrackEvent::EducationInfoViewed, anything,
        hash_excluding(:education_flow, :education_data_source, :nsc_status))
    end

    it "tracks verification without sending identity fields" do
      get :verify, params: { education_type: "college_or_university" }

      expect(EventTrackingJob).to have_received(:perform_later).with(
        TrackEvent::EducationVerificationViewed, anything,
        hash_including(cbv_flow_id: activity_flow.id, education_flow: "nsc", education_type: "college_or_university"))
      expect(EventTrackingJob).not_to have_received(:perform_later).with(anything, anything,
        hash_including(first_name: anything))
    end

    it "does not track verification when NSC is disabled" do
      stub_environment_variable("NSC_DISABLED", "true") { get :verify }

      expect(EventTrackingJob).not_to have_received(:perform_later)
    end

    it "does not count a loading-page redirect as a view" do
      allow(controller).to receive(:testing_synchronization_page?).and_return(false)
      get :show, params: { id: education_activity.id }

      expect(response).to have_http_status(:redirect)
      expect(EventTrackingJob).not_to have_received(:perform_later).with(TrackEvent::EducationSynchronizationViewed, anything, anything)
    end

    it "does not load error context from another applicant's activity" do
      other_activity = create(:education_activity)

      expect { get :error, params: { education_id: other_activity.id } }.to raise_error(ActiveRecord::RecordNotFound)
      expect(EventTrackingJob).not_to have_received(:perform_later)
    end

    it "tracks the loading page" do
      education_activity.update!(status: :unknown)
      get :show, params: { id: education_activity.id }

      expect(EventTrackingJob).to have_received(:perform_later).with(
        TrackEvent::EducationSynchronizationViewed, anything,
        hash_including(education_activity_id: education_activity.id, education_data_source: "pending")).once
    end

    it "does not track each poll as a page view or lookup result" do
      education_activity.update!(status: :unknown)
      patch :sync, params: { education_id: education_activity.id }, format: :turbo_stream
      patch :sync, params: { education_id: education_activity.id }, format: :turbo_stream

      expect(EventTrackingJob).not_to have_received(:perform_later).with(TrackEvent::EducationSynchronizationViewed, anything, anything)
      expect(EventTrackingJob).not_to have_received(:perform_later).with(TrackEvent::EducationNscLookupCompleted, anything, anything)
    end

    it "tracks the error page with the lookup's identity and status" do
      education_activity.update!(status: :no_enrollments)
      get :error, params: { education_id: education_activity.id }

      expect(EventTrackingJob).to have_received(:perform_later).with(
        TrackEvent::EducationNscErrorViewed, anything, event_attributes)
      expect(Capybara.string(response.body)).to have_selector('[data-activity-flow-header-track-event-prefix-value="Education"]')
    end

    it "tags enrollment review and navigation with partial self-attestation" do
      education_activity.update!(data_source: :partially_self_attested)
      get :edit, params: { id: education_activity.id, from_edit: 1 }

      expect(EventTrackingJob).to have_received(:perform_later).with(
        TrackEvent::EducationEnrollmentReviewViewed, anything, event_attributes)
      header = Capybara.string(response.body).find('[data-controller="activity-flow-header"]')
      attributes = JSON.parse(header["data-activity-flow-header-track-event-attributes-value"])
      expect(attributes).to include("education_activity_id" => education_activity.id,
        "education_data_source" => "partially_self_attested", "from_edit" => "1")
    end
  end

  describe "flow lifecycle" do
    it "tracks the start when an NSC lookup is requested" do
      post :create, params: { education_type: "college_or_university" }

      expect(EventTrackingJob).to have_received(:perform_later).with(
        TrackEvent::EducationFlowStarted, anything,
        hash_including(education_activity_id: activity_flow.education_activities.last.id,
          education_data_source: "pending", education_flow: "nsc"))
    end

    it "completes a validated flow only on its first successful publication" do
      patch :update, params: { id: education_activity.id, education_activity: { additional_comments: "" } }
      patch :update, params: { id: education_activity.id, education_activity: { additional_comments: "" } }

      expect(EventTrackingJob).to have_received(:perform_later).with(
        TrackEvent::EducationFlowCompleted, anything, event_attributes).once
    end

    context "with partial self-attestation" do
      before do
        education_activity.update!(data_source: :partially_self_attested)
        create(:nsc_enrollment_term, :less_than_half_time, education_activity: education_activity)
      end

      it "does not complete before credit hours, uploads, and review" do
        patch :update, params: { id: education_activity.id, education_activity: { additional_comments: "" } }

        expect(EventTrackingJob).to have_received(:perform_later).with(
          TrackEvent::EducationEnrollmentReviewSubmitted, anything, event_attributes)
        expect(EventTrackingJob).not_to have_received(:perform_later).with(TrackEvent::EducationFlowCompleted, anything, anything)
      end

      it "completes when the user saves the final review" do
        patch :save_review, params: { id: education_activity.id, education_activity: { additional_comments: "" } }

        expect(EventTrackingJob).to have_received(:perform_later).with(
          TrackEvent::EducationFlowCompleted, anything, event_attributes)
        expect(EventTrackingJob).to have_received(:perform_later).with(
          TrackEvent::EducationReviewSubmitted, anything, event_attributes)
      end
    end

    context "with fully self-attested education" do
      let(:education_activity) { create(:education_activity, :with_self_attested_term, activity_flow: activity_flow) }

      it "does not add NSC lifecycle events to the manual flow" do
        patch :save_review, params: { id: education_activity.id, education_activity: { additional_comments: "" } }

        expect(EventTrackingJob).not_to have_received(:perform_later).with(TrackEvent::EducationFlowCompleted, anything, anything)
        expect(EventTrackingJob).to have_received(:perform_later).with(
          TrackEvent::EducationReviewSubmitted, anything, hash_excluding(:education_flow, :education_data_source))
      end
    end
  end
end

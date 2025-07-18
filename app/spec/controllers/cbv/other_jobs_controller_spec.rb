require "rails_helper"

RSpec.describe Cbv::OtherJobsController do
  let(:cbv_flow) { create(:cbv_flow, :invited) }

  before do
    session[:cbv_flow_id] = cbv_flow.id
  end

  describe "#show" do
    render_views

    it "renders" do
      get :show
      expect(response).to be_successful
    end
  end

  describe "#update" do
    it 'redirects when has_other_jobs is true' do
      patch :update, params: { cbv_flow: { has_other_jobs: 'true' } }
      expect(response).to redirect_to(cbv_flow_applicant_information_path)
    end

    it 'redirects when has_other_jobs is false' do
      patch :update, params: { cbv_flow: { has_other_jobs: 'false' } }
      expect(response).to redirect_to(cbv_flow_applicant_information_path)
    end

    it 'redirects with notice when no radio button has been selected' do
      patch :update, params: { cbv_flow: { has_other_jobs: '' } }
      expect(flash[:slim_alert]).to be_present
      expect(response).to redirect_to(cbv_flow_other_job_path)
    end

    it 'tracks an event when has_other_jobs is true' do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)

      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantContinuedFromOtherJobsPage", anything, hash_including(
        timestamp: be_a(Integer),
        cbv_flow_id: cbv_flow.id,
        client_agency_id: cbv_flow.client_agency_id,
        has_other_jobs: true
      ))
      patch :update, params: { cbv_flow: { has_other_jobs: 'true' } }
    end

    it 'tracks an event when has_other_jobs is false' do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)

      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantContinuedFromOtherJobsPage", anything, hash_including(
        timestamp: be_a(Integer),
        cbv_flow_id: cbv_flow.id,
        client_agency_id: cbv_flow.client_agency_id,
        has_other_jobs: false
      ))
      patch :update, params: { cbv_flow: { has_other_jobs: 'false' } }
    end

    it 'does not track ApplicantContinuedFromOtherJobsPage event when no radio button is selected' do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)

      expect(EventTrackingJob).not_to receive(:perform_later).with("ApplicantContinuedFromOtherJobsPage", anything, anything)
      patch :update, params: { cbv_flow: { has_other_jobs: '' } }
    end

    context "when event tracking fails in production" do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.logger).to receive(:error)
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
      end

      it 'logs error and continues when event tracking raises an exception' do
        allow(EventTrackingJob).to receive(:perform_later).with("ApplicantContinuedFromOtherJobsPage", anything, anything).and_raise(StandardError)
        expect(Rails.logger).to receive(:error).with(/Unable to track ApplicantContinuedFromOtherJobsPage event/)

        patch :update, params: { cbv_flow: { has_other_jobs: 'true' } }
        expect(response).to redirect_to(cbv_flow_applicant_information_path)
      end
    end
  end
end

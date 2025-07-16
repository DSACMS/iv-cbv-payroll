require "rails_helper"

RSpec.describe Cbv::AddJobsController do
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

  describe "#create" do
    it 'redirects when true radio button is selected' do
      post :create, params: { 'additional_jobs': 'true' }
      expect(response).to redirect_to(cbv_flow_employer_search_path)
    end

    it 'redirects when false radio button is selected' do
      post :create, params: { 'additional_jobs': 'false' }
      expect(response).to redirect_to(cbv_flow_other_job_path)
    end

    it 'redirects with notice when no radio button has been selected' do
      post :create
      expect(flash[:slim_alert]).to be_present
      expect(response).to redirect_to(cbv_flow_add_job_path)
    end

    it 'tracks an event when true radio button is selected' do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)

      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantContinuedFromAddJobsPage", anything, hash_including(
        timestamp: be_a(Integer),
        cbv_flow_id: cbv_flow.id,
        client_agency_id: cbv_flow.client_agency_id,
        has_additional_jobs: true
      ))
      post :create, params: { 'additional_jobs': 'true' }
    end

    it 'tracks an event when false radio button is selected' do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)

      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantContinuedFromAddJobsPage", anything, hash_including(
        timestamp: be_a(Integer),
        cbv_flow_id: cbv_flow.id,
        client_agency_id: cbv_flow.client_agency_id,
        has_additional_jobs: false
      ))
      post :create, params: { 'additional_jobs': 'false' }
    end

    it 'does not track ApplicantContinuedFromAddJobsPage event when no radio button is selected' do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)

      expect(EventTrackingJob).not_to receive(:perform_later).with("ApplicantContinuedFromAddJobsPage", anything, anything)
      post :create
    end

    context "when event tracking fails in production" do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.logger).to receive(:error)
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
      end

      it 'logs error and continues when event tracking raises an exception' do
        allow(EventTrackingJob).to receive(:perform_later).with("ApplicantContinuedFromAddJobsPage", anything, anything).and_raise(StandardError.new("Event tracking failed"))
        expect(Rails.logger).to receive(:error).with(/Unable to track ApplicantContinuedFromAddJobsPage event/)

        post :create, params: { 'additional_jobs': 'true' }
        expect(response).to redirect_to(cbv_flow_employer_search_path)
      end
    end
  end
end

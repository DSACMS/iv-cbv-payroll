require "rails_helper"

RSpec.describe Cbv::AddJobsController do
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
      expect(response).to redirect_to(cbv_flow_summary_path)
    end

    it 'redirects with notice when no radio button has been selected' do
      post :create
      expect(flash[:slim_alert]).to be_present
      expect(response).to redirect_to(cbv_flow_add_job_path)
    end
  end
end

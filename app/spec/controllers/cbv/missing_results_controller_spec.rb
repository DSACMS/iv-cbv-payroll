require "rails_helper"

RSpec.describe Cbv::MissingResultsController do
  describe "#show" do
     render_views

     let(:cbv_flow) { create(:cbv_flow, :invited) }

     before do
       session[:cbv_flow_id] = cbv_flow.id
     end

     it "renders successfully" do
       get :show
       expect(response).to be_successful
     end

     context "when the user has already linked a pinwheel account" do
       let!(:payroll_account) { create(:payroll_account, cbv_flow: cbv_flow) }

       it "renders successfully" do
         get :show
         expect(response).to be_successful
       end
     end

     context "when the cbv_flow has a fully_synced payroll account" do
       let!(:payroll_account) { create(:payroll_account, :argyle_fully_synced, cbv_flow: cbv_flow) }

       it "renders the link in the view" do
         get :show
         expect(response.body).to include(cbv_flow_applicant_information_path)
       end
     end

     context "when the cbv_flow does not have a fully_synced payroll account" do
       let!(:payroll_account) { create(:payroll_account, :argyle_sync_in_progress, cbv_flow: cbv_flow) }

       it "does not render the link in the view" do
         get :show
         expect(response.body).not_to include(cbv_flow_applicant_information_path)
       end
     end
   end
end

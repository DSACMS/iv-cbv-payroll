require "rails_helper"

RSpec.describe Cbv::BaseController, type: :controller do
  controller(described_class) do
    def show
      render plain: "hello world"
    end
  end

  let(:cbv_flow) { create(:cbv_flow, :invited, client_agency_id: "az_des") }

  describe '#track_invitation_clicked_event' do
    before do
      routes.draw do
        get 'show', controller: "cbv/base"
      end
    end

    let(:cbv_flow_2) { create(:cbv_flow, cbv_flow_invitation: cbv_flow.cbv_flow_invitation) }

    it "identifies multiple household members if income changes relevant" do
      cbv_flow.cbv_flow_invitation.cbv_applicant.update!(
        income_changes: [
        {
            member_name: "Dean Venture"
          },
        {
            member_name: "Hank Venture"
          },
         {
            member_name: "Hank Venture"
          },
         {
            member_name: "Dr Venture"
          } ]
        )
      expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          household_member_count: 3
          ))
      get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token }
      expect(response).to be_successful
      expect(response.body).to eq("hello world")
    end

    it "identifies one household member if no income changes relevant" do
      create(:cbv_flow, cbv_flow_invitation: cbv_flow.cbv_flow_invitation)
      expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          household_member_count: 1
          ))
      get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token }
      expect(response).to be_successful
      expect(response.body).to eq("hello world")
    end

    it "identifies number_links_started from cbv flows generated" do
      create(:cbv_flow, cbv_flow_invitation: cbv_flow.cbv_flow_invitation)
      expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          flows_started_count: 3
          ))
      get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token }
      expect(response).to be_successful
      expect(response.body).to eq("hello world")
    end

    context "when handling origin parameters" do
      before do
        stub_client_agency_config_value("la_ldh", "agency_domain", "la.reportmyincome.org")
        request.host = "la.reportmyincome.org"
      end

      it "sets the origin in the clicked invitation event" do
        expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          origin: "email"
        ))
        get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token, origin: "email" }
        expect(response).to be_successful
        expect(session[:cbv_flow_id]).to be_a(Integer)
        expect(session[:cbv_origin]).to eq "email"
      end

      it "cleans the supplied origin parameter if set" do
        expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          origin: "mfb_dashboard"
        ))
        get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token, origin: " MFB dashboard" }
        expect(response).to be_successful
        expect(session[:cbv_flow_id]).to be_a(Integer)
        expect(session[:cbv_origin]).to eq "mfb_dashboard"
      end

      it "does not reset the origin if it is already present" do
        session[:cbv_origin] = "test"
        expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          origin: "test"
        ))
        get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token, origin: "email" }
        expect(response).to be_successful
        expect(session[:cbv_flow_id]).to be_a(Integer)
        expect(session[:cbv_origin]).to eq "test"
      end

      it "does not set an origin if no parameter or agency default are supplied" do
        request.host = nil
        expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          origin: nil
        ))
        get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token }
        expect(response).to be_successful
        expect(session[:cbv_flow_id]).to be_a(Integer)
        expect(session[:cbv_origin]).to be_nil
      end
    end
  end
end

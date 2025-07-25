require "rails_helper"

RSpec.describe Cbv::BaseController, type: :controller do
  controller(described_class) do
    def show
      render plain: "hello world"
    end
  end

  let(:cbv_flow) { create(:cbv_flow, :invited, client_agency_id: "az_des") }

  before do
    routes.draw do
      get 'show', controller: "cbv/base"
    end
  end

  describe '#set_cbv_flow' do
    it "sets an encrypted permanent cookie with cbv_applicant_id for invitation-based flows" do
      get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token }

      expect(cookies.encrypted[:cbv_applicant_id]).to eq(cbv_flow.cbv_applicant_id)

      cookie_jar = response.cookies["cbv_applicant_id"]
      expect(cookie_jar).to be_present
    end
  end

  describe '#track_invitation_clicked_event' do
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
  end
end

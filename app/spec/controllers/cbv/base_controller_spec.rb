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

    context "when no token or session is present" do
      it "redirects to root with cbv_flow_timeout parameter and flash message" do
        get :show
        expect(response).to redirect_to(root_url(cbv_flow_timeout: true))
        expect(flash[:slim_alert]).to eq({
          type: "info",
          message_html: I18n.t("cbv.error_missing_token_html")
        })
      end
    end

    context "when cbv flow cannot be found for session" do
      it "redirects to root with cbv_flow_timeout parameter" do
        session[:cbv_flow_id] = 1337
        get :show
        expect(response).to redirect_to(root_url(cbv_flow_timeout: true))
      end
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

    context "when handling origin parameters" do
      before do
        stub_client_agency_config_value("la_ldh", "agency_domain", "la.verifymyincome.org")
        request.host = "la.verifymyincome.org"
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

      it "resets the origin if it is already present" do
        session[:cbv_origin] = "test"
        expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          origin: "email"
        ))
        get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token, origin: "email" }
        expect(response).to be_successful
        expect(session[:cbv_flow_id]).to be_a(Integer)
        expect(session[:cbv_origin]).to eq "email"
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

      it "does set an origin if no parameter is supplied but agency default exists" do
        stub_client_agency_config_value("la_ldh", "default_origin", "sms")
        expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          origin: "sms"
        ))
        get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token }
        expect(response).to be_successful
        expect(session[:cbv_flow_id]).to be_a(Integer)
        expect(session[:cbv_origin]).to eq "sms"
      end
    end
  end
end

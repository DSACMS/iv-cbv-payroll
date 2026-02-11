require "rails_helper"

RSpec.describe Cbv::BaseController, type: :controller do
  controller(described_class) do
    def show
      render plain: "hello world"
    end
  end

  let(:cbv_flow) { create(:cbv_flow, :invited) }

  before do
    routes.draw do
      get 'show', controller: "cbv/base"
    end
  end

  describe '#set_cbv_flow' do
    context "when no token or session is present" do
      it "redirects to root with cbv_flow_timeout parameter and flash message" do
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantAccessedFlowWithoutCookie", anything, hash_including(
          time: kind_of(Integer)
        ))
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
        session[:flow_id] = 1337
        session[:flow_type] = :cbv
        get :show
        expect(response).to redirect_to(root_url(cbv_flow_timeout: true))
        expect(session[:flow_id]).to be_nil
        expect(session[:flow_type]).to be_nil
      end
    end

    describe "setting @cbv_flow and current_agency" do
      let(:cbv_flow) { create(:cbv_flow, cbv_applicant_attributes: attributes_for(:cbv_applicant, :sandbox)) }
      let(:domain) { "fake-domain-for-la-ldh.localhost" }

      before do
        session[:flow_id] = cbv_flow.id

        request.host = domain
        allow(Rails.application.config.client_agencies["la_ldh"])
          .to receive(:agency_domain)
          .and_return(domain)
      end

      it "sets the current_agency based on the @cbv_flow (not the domain)" do
        get :show
        expect(assigns[:current_agency]).to have_attributes(id: "sandbox")
      end
    end
  end

  describe '#track_invitation_clicked_event' do
    let(:cbv_flow_2) { create(:cbv_flow, cbv_flow_invitation: cbv_flow.cbv_flow_invitation) }

    it "identifies multiple household members if income changes relevant" do
      cbv_flow.cbv_flow_invitation.cbv_applicant.update!(
        income_changes: [
          { member_name: "Dean Venture" },
          { member_name: "Hank Venture" },
          { member_name: "Hank Venture" },
          { member_name: "Dr Venture" } ]
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
        expect(session[:flow_id]).to be_a(Integer)
        expect(session[:cbv_origin]).to eq "email"
      end

      it "cleans the supplied origin parameter if set" do
        expect(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with("ApplicantClickedCBVInvitationLink", anything, hash_including(
          origin: "mfb_dashboard"
        ))
        get :show, params: { token: cbv_flow.cbv_flow_invitation.auth_token, origin: " MFB dashboard" }
        expect(response).to be_successful
        expect(session[:flow_id]).to be_a(Integer)
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
        expect(session[:flow_id]).to be_a(Integer)
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
        expect(session[:flow_id]).to be_a(Integer)
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
        expect(session[:flow_id]).to be_a(Integer)
        expect(session[:cbv_origin]).to eq "sms"
      end
    end
  end

  describe "#append_log_tags" do
    controller(described_class) do
      def show
        render json: Rails.logger.formatter.tag_stack.tags
      end
    end

    around do |ex|
      stub_environment_variable("STRUCTURED_LOGGING_ENABLED", "true", &ex)
    end

    context "with a CbvFlow" do
      let(:flow) { create(:cbv_flow) }

      before do
        session[:flow_id] = flow.id
        session[:flow_type] = :cbv
      end

      it "adds log tags" do
        get :show, params: { id: "foo" }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).first.symbolize_keys).to match(
          flow_id: flow.id,
          flow_type: "CbvFlow",
          invitation_id: flow.invitation_id,
          cbv_applicant_id: flow.cbv_applicant_id,
          client_agency_id: flow.cbv_applicant.client_agency_id,
          device_id: be_a(String)
        )
      end
    end

    context "for an activity flow" do
      let(:flow) { create(:activity_flow) }

      before do
        session[:flow_id] = flow.id
        session[:flow_type] = :activity
      end

      it "adds log tags" do
        get :show, params: { id: "foo" }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).first.symbolize_keys).to match(
          flow_id: flow.id,
          flow_type: "ActivityFlow",
          invitation_id: flow.invitation_id,
          cbv_applicant_id: flow.cbv_applicant_id,
          client_agency_id: flow.cbv_applicant.client_agency_id,
          device_id: be_a(String)
        )
      end
    end
  end
end

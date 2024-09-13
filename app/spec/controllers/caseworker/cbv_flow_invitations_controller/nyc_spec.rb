require "rails_helper"

RSpec.describe Caseworker::CbvFlowInvitationsController, type: :controller do
  let(:user) { create(:user, email: "test@test.com", site_id: 'nyc') }
  let(:nyc_params) { { site_id: "nyc" } }

  before do
    sign_in user
  end

  describe "#new" do
    let(:valid_params) { nyc_params }

    context "loads the nyc fields" do
      render_views

      it "renders the nyc fields" do
        get :new, params: nyc_params
        expect(response.body).to include("first_name")
        expect(response.body).to include("middle_name")
        expect(response.body).to include("last_name")
        expect(response.body).to include("client_id_number")
        expect(response.body).to include("case_number")
        expect(response.body).to include("email_address")
        expect(response.body).to include("snap_application_date")
      end
    end
  end

  describe "#create" do
    let(:valid_case_number) { "11111111111A" }
    let(:valid_client_id_number) { "AV54126B" }
    let(:cbv_flow_invitation_params) do
      attributes_for(:cbv_flow_invitation, site_id: "nyc", client_id_number: valid_client_id_number, case_number: valid_case_number)
    end

    it "creates a CbvFlowInvitation record with the nyc fields" do
      post :create, params: {
        site_id: nyc_params[:site_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }

      invitation = CbvFlowInvitation.last
      expect(invitation.first_name).to eq("Jane")
      expect(invitation.middle_name).to eq("Sue")
      expect(invitation.last_name).to eq("Doe")
      expect(invitation.client_id_number).to eq(valid_client_id_number)
      expect(invitation.case_number).to eq(valid_case_number)
      expect(invitation.email_address).to eq("test@example.com")
    end

    it "creates a CbvFlowInvitation record without optional fields" do
      post :create, params: {
        site_id: nyc_params[:site_id],
        cbv_flow_invitation: cbv_flow_invitation_params.except(:middle_name, :client_id_number)
      }
      puts response.inspect
      invitation = CbvFlowInvitation.last
      expect(invitation.middle_name).to be_nil
    end

    it "redirects back to the caseworker dashboard" do
      post :create, params: {
        site_id: nyc_params[:site_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }

      expect(response).to redirect_to(caseworker_dashboard_path(site_id: nyc_params[:site_id]))
    end

    it "sends an event to NewRelic" do
      allow(NewRelicEventTracker).to receive(:track)

      post :create, params: {
        site_id: nyc_params[:site_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }

      invitation = CbvFlowInvitation.last
      expect(NewRelicEventTracker).to have_received(:track).with("ApplicantInvitedToFlow", {
        timestamp: be_a(Integer),
        user_id: user.id,
        caseworker_email_address: user.email,
        site_id: "nyc",
        invitation_id: invitation.id
      })
    end
  end
end

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
    let(:cbv_flow_invitation_params) do
      attributes_for(:cbv_flow_invitation, :nyc)
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
      expect(invitation.client_id_number).to eq(cbv_flow_invitation_params[:client_id_number])
      expect(invitation.case_number).to eq(cbv_flow_invitation_params[:case_number])
      expect(invitation.email_address).to eq("test@example.com")
    end

    it "creates a CbvFlowInvitation record without optional fields" do
      post :create, params: {
        site_id: nyc_params[:site_id],
        cbv_flow_invitation: cbv_flow_invitation_params.except(:middle_name)
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

    # Note that we are not testing events here because doing so requires use of expect_any_instance_of,
    # which does not play nice since there are multiple instances of the event logger.

    context "when validations succeed" do
      it "creates a cbv_client record" do
        expect {
          post :create, params: {
            site_id: nyc_params[:site_id],
            cbv_flow_invitation: cbv_flow_invitation_params
          }
        }.to change(CbvClient, :count).by(1)

        client = CbvClient.last
        expect(client.first_name).to eq("Jane")
      end
    end

    context "when validations fail" do
      before do
        cbv_flow_invitation_params[:first_name] = nil
      end

      it "does not create a cbv_client record" do
        expect {
          post :create, params: {
            site_id: nyc_params[:site_id],
            cbv_flow_invitation: cbv_flow_invitation_params
          }
        }.to change(CbvClient, :count).by(0)
      end
    end
  end
end

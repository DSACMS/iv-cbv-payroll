require "rails_helper"

RSpec.describe CbvFlowInvitationsController, type: :controller do
  let(:user) { User.create(email: "test@test.com", site_id: 'nyc') }
  let(:invite_secret) { "FAKE_INVITE_SECRET" }
  let(:nyc_params) { { site_id: "nyc", secret: invite_secret } }

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
        attributes_for(:cbv_flow_invitation, site_id: "nyc", client_id_number: "123456", case_number: "ABC1234")
      end

      context "successfully creates a CbvFlowInvitation record with the nyc fields" do
        it "creates a CbvFlowInvitation record with the nyc fields" do
          post :create, params: {
            secret: invite_secret,
            site_id: nyc_params[:site_id],
            cbv_flow_invitation: cbv_flow_invitation_params
          }

          invitation = CbvFlowInvitation.last
          expect(invitation.first_name).to eq("Jane")
          expect(invitation.middle_name).to eq("Sue")
          expect(invitation.last_name).to eq("Doe")
          expect(invitation.client_id_number).to eq("123456")
          expect(invitation.case_number).to eq("ABC1234")
          expect(invitation.email_address).to eq("test@example.com")
        end

        it "creates a CbvFlowInvitation record without optional fields" do
          post :create, params: {
            secret: invite_secret,
            site_id: nyc_params[:site_id],
            cbv_flow_invitation: cbv_flow_invitation_params.except(:middle_name, :client_id_number)
          }
          invitation = CbvFlowInvitation.last
          expect(invitation.middle_name).to be_nil
        end
      end
    end
end

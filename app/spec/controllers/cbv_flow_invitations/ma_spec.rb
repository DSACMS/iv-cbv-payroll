require "rails_helper"

RSpec.describe CbvFlowInvitationsController, type: :controller do
  let(:invite_secret) { "FAKE_INVITE_SECRET" }
  let(:user) { User.create(email: "test@test.com", site_id: 'ma') }
  let(:ma_params) { { site_id: "ma", secret: invite_secret } }

  before do
    sign_in user
  end

  describe "#new" do
    let(:valid_params) { ma_params }

    context "loads the ma fields" do
      render_views

      it "renders the ma fields" do
        get :new, params: ma_params
        expect(response.body).to include("first_name")
        expect(response.body).to include("middle_name")
        expect(response.body).to include("last_name")
        expect(response.body).to include("agency_id_number")
        expect(response.body).to include("email_address")
        expect(response.body).to include("snap_application_date")
        expect(response.body).to include("beacon_id")
      end
    end
  end

  describe "#create" do
    let(:error_message) do
      "Error sending invitation to test@example.com: " \
        "Validation failed: Agency id number can't be blank, Beacon can't be blank."
    end

    let(:cbv_flow_invitation_params) do
      attributes_for(:cbv_flow_invitation, site_id: "ma", beacon_id: "ABC123", agency_id_number: "789012")
    end

    it "creates a CbvFlowInvitation record with the ma fields" do
      post :create, params: {
        secret: invite_secret,
        site_id: ma_params[:site_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }

      invitation = CbvFlowInvitation.all.last
      expect(invitation.first_name).to eq("Jane")
      expect(invitation.middle_name).to eq("Sue")
      expect(invitation.last_name).to eq("Doe")
      expect(invitation.agency_id_number).to eq("789012")
      expect(invitation.email_address).to eq("test@example.com")
      expect(invitation.snap_application_date).to eq(Date.today)
      expect(invitation.beacon_id).to eq("ABC123")
    end

    it "requires the ma fields" do
      post :create, params: {
        secret: invite_secret,
        site_id: "ma",
        cbv_flow_invitation: cbv_flow_invitation_params.except(:beacon_id, :agency_id_number)
      }
      expect(flash[:alert]).to eq(error_message)
    end
  end
end

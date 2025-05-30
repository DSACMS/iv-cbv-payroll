require "rails_helper"

RSpec.describe Caseworker::CbvFlowInvitationsController, type: :controller do
  let(:user) { create(:user, email: "test@test.com", client_agency_id: 'nyc') }
  let(:nyc_params) { { client_agency_id: "nyc" } }

  before do
    stub_client_agency_config_value("nyc", "staff_portal_enabled", true)
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
      attributes_for(:cbv_flow_invitation, :nyc).merge(
        cbv_applicant_attributes: attributes_for(:cbv_applicant, :nyc)
      )
    end

    it "creates a CbvFlowInvitation record with the nyc fields" do
      post :create, params: {
        client_agency_id: nyc_params[:client_agency_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }

      invitation = CbvFlowInvitation.last
      applicant = invitation.cbv_applicant
      expect(applicant.first_name).to eq("Jane")
      expect(applicant.middle_name).to eq("Sue")
      expect(applicant.last_name).to eq("Doe")
      expect(applicant.client_id_number).to eq(cbv_flow_invitation_params[:cbv_applicant_attributes][:client_id_number])
      expect(applicant.case_number).to eq(cbv_flow_invitation_params[:cbv_applicant_attributes][:case_number])
      expect(invitation.email_address).to eq("test@example.com")
    end

    it "creates a CbvFlowInvitation record without optional fields" do
      cbv_flow_invitation_params[:cbv_applicant_attributes].delete(:middle_name)

      post :create, params: {
        client_agency_id: nyc_params[:client_agency_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }
      invitation = CbvFlowInvitation.last
      expect(invitation.cbv_applicant.middle_name).to be_nil
    end

    it "redirects back to the caseworker dashboard" do
      post :create, params: {
        client_agency_id: nyc_params[:client_agency_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }

      expect(response).to redirect_to(caseworker_dashboard_path(client_agency_id: nyc_params[:client_agency_id]))
    end

    # Note that we are not testing events here because doing so requires use of expect_any_instance_of,
    # which does not play nice since there are multiple instances of the event logger.

    context "when validations succeed" do
      it "creates a cbv_applicant record" do
        expect {
          post :create, params: {
            client_agency_id: nyc_params[:client_agency_id],
            cbv_flow_invitation: cbv_flow_invitation_params
          }
        }.to change(CbvApplicant, :count).by(1)

        client = CbvApplicant.last
        expect(client.first_name).to eq("Jane")
      end
    end

    context "when validations fail" do
      before do
        cbv_flow_invitation_params[:cbv_applicant_attributes][:first_name] = nil
      end

      it "does not create a cbv_applicant record" do
        expect {
          post :create, params: {
            client_agency_id: nyc_params[:client_agency_id],
            cbv_flow_invitation: cbv_flow_invitation_params
          }
        }.to change(CbvApplicant, :count).by(0)
      end
    end
  end
end

require "rails_helper"

RSpec.describe Caseworker::CbvFlowInvitationsController, type: :controller do
  let(:user) { create(:user, email: "test@test.com", client_agency_id: 'ma') }
  let(:ma_params) { { client_agency_id: "ma" } }

  before do
    stub_client_agency_config_value("ma", "staff_portal_enabled", true)
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

      it "renders the header for MA" do
        get :new, params: ma_params
        expect(response.body).to include(I18n.t("shared.header.cbv_flow_title.ma"))
      end
    end
  end

  describe "#create" do
    let(:cbv_flow_invitation_params) do
      attributes_for(:cbv_flow_invitation, :ma).merge(
        cbv_applicant_attributes: attributes_for(:cbv_applicant, :ma)
      )
    end

    it "creates a CbvFlowInvitation record with the ma fields" do
      post :create, params: {
        client_agency_id: ma_params[:client_agency_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }
      expect(response).to have_http_status(:found)

      invitation = CbvFlowInvitation.last
      applicant = invitation.cbv_applicant
      expect(applicant.first_name).to eq("Jane")
      expect(applicant.middle_name).to eq("Sue")
      expect(applicant.last_name).to eq("Doe")
      expect(applicant.agency_id_number).to eq(cbv_flow_invitation_params[:cbv_applicant_attributes][:agency_id_number])
      expect(invitation.email_address).to eq("test@example.com")
      expect(applicant.snap_application_date).to eq(Date.current)
      expect(applicant.beacon_id).to eq(cbv_flow_invitation_params[:cbv_applicant_attributes][:beacon_id])
    end

    it "requires the ma fields" do
      cbv_flow_invitation_params[:cbv_applicant_attributes].delete(:beacon_id)
      cbv_flow_invitation_params[:cbv_applicant_attributes].delete(:agency_id_number)

      post :create, params: {
        client_agency_id: "ma",
        cbv_flow_invitation: cbv_flow_invitation_params
      }
      expected_errors = [
        I18n.t('activerecord.errors.models.cbv_applicant/ma.attributes.agency_id_number.invalid_format'),
        I18n.t('activerecord.errors.models.cbv_applicant/ma.attributes.beacon_id.invalid_format')
      ]
      expected_error_message = "<ul><li>#{expected_errors.join('</li><li>')}</li></ul>"
      expect(flash[:alert]).to eq(expected_error_message)
    end

    it "redirects back to the caseworker dashboard" do
      post :create, params: {
        client_agency_id: ma_params[:client_agency_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }

      expect(response).to redirect_to(caseworker_dashboard_path(client_agency_id: ma_params[:client_agency_id]))
    end
  end
end

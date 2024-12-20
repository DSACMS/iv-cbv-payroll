require "rails_helper"

RSpec.describe Caseworker::CbvFlowInvitationsController, type: :controller do
  let(:user) { create(:user, email: "test@test.com", site_id: 'ma') }
  let(:ma_params) { { site_id: "ma" } }

  before do
    stub_site_config_value("ma", "staff_portal_enabled", true)
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
      attributes_for(:cbv_flow_invitation, site_id: "ma", beacon_id: "ABC123", agency_id_number: "7890120")
    end

    it "creates a CbvFlowInvitation record with the ma fields" do
      post :create, params: {
        site_id: ma_params[:site_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }

      invitation = CbvFlowInvitation.all.last
      expect(invitation.first_name).to eq("Jane")
      expect(invitation.middle_name).to eq("Sue")
      expect(invitation.last_name).to eq("Doe")
      expect(invitation.agency_id_number).to eq("7890120")
      expect(invitation.email_address).to eq("test@example.com")
      expect(invitation.snap_application_date).to eq(Time.zone.today)
      expect(invitation.beacon_id).to eq("ABC123")
    end

    it "requires the ma fields" do
      post :create, params: {
        site_id: "ma",
        cbv_flow_invitation: cbv_flow_invitation_params.except(:beacon_id, :agency_id_number)
      }
      expected_errors = [
        I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.agency_id_number.invalid_format'),
        I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.beacon_id.invalid_format')
      ]
      expected_error_message = "<ul><li>#{expected_errors.join('</li><li>')}</li></ul>"
      expect(flash[:alert]).to eq(expected_error_message)
    end

    it "redirects back to the caseworker dashboard" do
      post :create, params: {
        site_id: ma_params[:site_id],
        cbv_flow_invitation: cbv_flow_invitation_params
      }

      expect(response).to redirect_to(caseworker_dashboard_path(site_id: ma_params[:site_id]))
    end
  end
end

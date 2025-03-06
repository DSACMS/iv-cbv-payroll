require "rails_helper"

RSpec.describe Api::InvitationsController do
  describe "#create" do
    # must be existing user
    let(:api_access_token) do
      user = create(:user, :with_access_token, email: "test@test.com", client_agency_id: 'ma', is_service_account: true)
      user.api_access_tokens.first
    end

    let(:valid_params) do
      attributes_for(:cbv_flow_invitation, :ma).tap do |params|
        params[:agency_partner_metadata] = attributes_for(:cbv_applicant, :ma)
      end
    end

    before do
      request.headers["Authorization"] = "Bearer #{api_access_token.access_token}"
    end

    it "creates an invitation with an associated cbv_applicant" do
      expect do
        post :create, params: valid_params
      end.to change(CbvFlowInvitation, :count).by(1)
        .and change(CbvApplicant, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body).keys).to include("tokenized_url")
    end

    context "invalid params" do
      let(:invalid_params) do
        valid_params[:agency_partner_metadata].delete(:first_name)
        valid_params.delete(:client_agency_id)
        valid_params
      end

      it "returns unprocessable entity with structured error response" do
        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        parsed_response = JSON.parse(response.body)

        # Check for structured error response
        expect(parsed_response).to have_key("errors")
        expect(parsed_response["errors"]).to be_an(Array)

        # Extract error fields for easier testing
        error_fields = parsed_response["errors"].map { |e| e["field"] }

        expect(error_fields).not_to include("cbv_applicant")
        expect(error_fields).to include("client_agency_id")
        expect(error_fields).to include("agency_partner_metadata.first_name")
      end
    end

    context "unauthorized user" do
      before do
        request.headers["Authorization"] = nil
      end

      it "returns unprocessable entity" do
        post :create, params: valid_params

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include("HTTP Token: Access denied.")
      end
    end

    context "invalid language" do
      let(:invalid_user_params) do
        valid_params.merge(language: "zn")
      end

      it "returns unprocessable entity" do
        post :create, params: invalid_user_params

        expect(response).to have_http_status(:unprocessable_entity)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to have_key("errors")
        expect(parsed_response["errors"].map { |e| e["field"] }).to include("language")
      end
    end

    context "with email_address outside of agency_partner_metadata" do
      let(:params_with_email_outside) do
        params = valid_params.deep_dup
        params[:email_address] = "direct@example.com"
        params
      end

      it "uses the provided email_address" do
        post :create, params: params_with_email_outside

        expect(response).to have_http_status(:created)
        invitation = CbvFlowInvitation.last
        expect(invitation.email_address).to eq("direct@example.com")
      end
    end

    context "with application_date instead of snap_application_date" do
      let(:params_with_application_date) do
        params = valid_params.deep_dup
        params[:agency_partner_metadata].delete(:snap_application_date)
        # Use ISO format (YYYY-MM-DD) to avoid ambiguity
        params[:application_date] = "2025-01-03"
        params
      end

      it "maps application_date to snap_application_date" do
        post :create, params: params_with_application_date

        expect(response).to have_http_status(:created)
        invitation = CbvFlowInvitation.last
        # January 3, 2025
        expect(invitation.cbv_applicant.snap_application_date).to eq(Date.new(2025, 1, 3))
      end
    end
  end
end

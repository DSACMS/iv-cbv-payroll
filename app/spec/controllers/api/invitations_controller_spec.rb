require "rails_helper"

RSpec.describe Api::InvitationsController do
  describe "#create" do
    # must be existing user
    let(:api_access_token) do
      user = create(:user, :with_access_token, email: "test@test.com", site_id: 'ma', is_service_account: true)
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
      expect(JSON.parse(response.body).keys).to include("url")
    end

    context "invalid params" do
      let(:invalid_params) do
        valid_params[:agency_partner_metadata].delete(:first_name)
        valid_params.delete(:site_id)
        valid_params
      end

      it "returns unprocessable entity" do
        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response.keys).not_to include("cbv_applicant")
        expect(parsed_response.keys).to include("site_id")
        expect(parsed_response.keys).to include("agency_partner_metadata.first_name")
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
        expect(JSON.parse(response.body).keys).to include("language")
      end
    end
  end
end

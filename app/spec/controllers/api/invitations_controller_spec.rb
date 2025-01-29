require "rails_helper"

RSpec.describe Api::InvitationsController do
  describe "#create" do
    # must be existing user
    let(:service_account_user) do
      create(:user, email: "test@test.com", site_id: 'ma')
    end

    let(:valid_params) do
      attributes_for(:cbv_flow_invitation,
        site_id: "ma",
        beacon_id: "ABC123",
        agency_id_number: "7890120",
        user_id: service_account_user.id
      )
    end

    it "creates an invitation" do
      post :create, params: valid_params
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body).keys).to include("url")
    end

    context "invalid params" do
      let(:invalid_params) do
        valid_params.except(:first_name)
      end

      it "returns unprocessable entity" do
        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body).keys).to include("first_name")
      end
    end

    context "invalid user" do
      let(:invalid_user_params) do
        valid_params.merge(user_id: 0)
      end

      it "returns unprocessable entity" do
        post :create, params: invalid_user_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body).keys).to include("error")
      end
    end
  end
end

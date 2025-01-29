require "rails_helper"

RSpec.describe Api::InvitationsController do
  describe "#create" do
    let(:valid_params) do
      attributes_for(:cbv_flow_invitation, site_id: "ma", beacon_id: "ABC123", agency_id_number: "7890120")
    end

    it "creates an invitation" do
      post :create, params: {
        site_id: :sandbox,
        cbv_flow_invitation: valid_params
      }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body).keys).to include("url")
    end

    context "invalid params" do
      let(:invalid_params) do
        valid_params.except(:first_name)
      end

      it "returns unprocessable entity" do
        post :create, params: {
          site_id: :sandbox,
          cbv_flow_invitation: invalid_params
        }
        pp response.body

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body).keys).to include("first_name")
      end
    end
  end
end

require "rails_helper"

RSpec.describe Api::V2::InvitationsController do
  describe "#create" do
    subject(:create_invitation) do
      post :create, params: valid_params
    end

    let(:client_agency_id) { "sandbox".to_sym }
    let(:api_access_token_instance) do
      user = create(:user, :with_access_token, email: "test@test.com", client_agency_id: client_agency_id, is_service_account: true)
      user.api_access_tokens.first
    end

    let(:valid_params) do
      attributes_for(:cbv_flow_invitation, client_agency_id).tap do |params|
        params[:type] = "income"
        params[:agency_partner_metadata] = attributes_for(:cbv_applicant, client_agency_id)
        # ensure that client_agency_id is not considered a valid param. it should be inferred from the api token
        params[:agency_partner_metadata].delete(:client_agency_id)
        params.delete(:client_agency_id)
      end
    end

    before do
      request.headers["Authorization"] = "Bearer #{api_access_token_instance.access_token}"
    end

    it "returns a 400 error for an invalid invitation type" do
      invalid_params = valid_params.merge(type: "invalid_type")
      post :create, params: invalid_params

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "Invalid invitation type")
    end

    it "returns 400 when type is missing" do
      post :create, params: valid_params.except(:type)

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "Invalid invitation type")
    end

    it "creates an invitation with an associated cbv_applicant" do
      expect { create_invitation }
          .to change(CbvFlowInvitation, :count).by(1)
          .and change(CbvApplicant, :count).by(1)

      expect(response).to have_http_status(:created)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to include("tokenized_url")
    end

    it "creates an invitation using the client_agency_id in the access_token" do
      expect { create_invitation }
          .to change(CbvFlowInvitation, :count).by(1)
          .and change(CbvApplicant, :count).by(1)

      invitation = CbvFlowInvitation.last
      expect(invitation.client_agency_id).to eq(client_agency_id.to_s)
    end

    context "when inviting a user in LA LDH" do
      let(:client_agency_id) { "la_ldh".to_sym }
      let(:valid_params) do
        attributes_for(:cbv_flow_invitation, client_agency_id).tap do |params|
          params[:type] = "income"
          params[:agency_partner_metadata] = {
            individual_id: "ABC1234"
          }
        end
      end

      it "creates an invitation" do
        expect { create_invitation }
          .to change(CbvFlowInvitation, :count).by(1)
          .and change(CbvApplicant, :count).by(1)

        invitation = CbvFlowInvitation.last
        expect(invitation.client_agency_id).to eq(client_agency_id.to_s)

        applicant = invitation.cbv_applicant
        expect(applicant.client_agency_id).to eq("la_ldh")
        expect(applicant.individual_id).to eq("ABC1234")
      end

      it "returns the expected agency_partner_metadata" do
        create_invitation
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["agency_partner_metadata"]).to eq(
          "individual_id" => valid_params[:agency_partner_metadata][:individual_id],
          "case_number" => valid_params[:agency_partner_metadata][:case_number],
          "date_of_birth" => valid_params[:agency_partner_metadata][:date_of_birth],
        )
      end

      it "returns 422 when both doc_id and individual_id are nil for income" do
        valid_params[:agency_partner_metadata] = {
          case_number: nil,
          date_of_birth: nil,
          individual_id: nil
        }

        post :create, params: valid_params

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          a_hash_including("message" => I18n.t("cbv.applicant_informations.la_ldh.fields.doc_id_or_individual_id.blank"))
        )
      end
    end
  end
end

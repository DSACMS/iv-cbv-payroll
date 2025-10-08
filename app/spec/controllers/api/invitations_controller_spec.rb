require "rails_helper"

RSpec.describe Api::InvitationsController do
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
        params[:agency_partner_metadata] = attributes_for(:cbv_applicant, client_agency_id)
        # ensure that client_agency_id is not considered a valid param. it should be inferred from the api token
        params[:agency_partner_metadata].delete(:client_agency_id)
        params.delete(:client_agency_id)
      end
    end

    before do
      request.headers["Authorization"] = "Bearer #{api_access_token_instance.access_token}"
    end

    it "creates an invitation and cbv_applicant" do
      expect { create_invitation }
        .to change(CbvFlowInvitation, :count).by(1)
                                             .and change(CbvApplicant, :count).by(1)
    end

    it "returns created status with tokenized_url" do
      create_invitation
      aggregate_failures do
        expect(response).to have_http_status(:created)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to include("tokenized_url")
      end
    end

    it "includes all agency_partner_metadata fields in the response" do
      create_invitation
      parsed_response = JSON.parse(response.body)
      expect(parsed_response["agency_partner_metadata"].keys.map(&:to_sym)).to match_array(
        CbvApplicant.valid_attributes_for_agency(client_agency_id.to_s)
      )
    end

    it "sets the correct client_agency_id from access_token" do
      create_invitation
      invitation = CbvFlowInvitation.last
      expect(invitation.client_agency_id).to eq(client_agency_id.to_s)
    end

    context "when inviting a user in AZ DES" do
      let(:client_agency_id) { "az_des".to_sym }

      it "creates an invitation and applicant" do
        expect { create_invitation }
          .to change(CbvFlowInvitation, :count).by(1)
                                               .and change(CbvApplicant, :count).by(1)
      end

      it "sets correct client_agency_id and income_changes" do
        create_invitation
        invitation = CbvFlowInvitation.last
        applicant = invitation.cbv_applicant

        aggregate_failures do
          expect(invitation.client_agency_id).to eq(client_agency_id.to_s)
          expect(applicant.client_agency_id).to eq("az_des")
          expect(applicant.income_changes.length).to eq(2)
          expect(applicant.income_changes[0]["member_name"]).to eq("Mark Scout")
        end
      end
    end

    context "when inviting a user in LA LDH" do
      let(:client_agency_id) { "la_ldh".to_sym }
      let(:valid_params) do
        attributes_for(:cbv_flow_invitation, client_agency_id).tap do |params|
          params[:agency_partner_metadata] = {
            doc_id: "ABC1234"
          }
        end
      end

      it "creates an invitation and applicant" do
        expect { create_invitation }
          .to change(CbvFlowInvitation, :count).by(1)
                                               .and change(CbvApplicant, :count).by(1)
      end

      it "sets correct client_agency_id and doc_id" do
        create_invitation
        invitation = CbvFlowInvitation.last
        applicant = invitation.cbv_applicant

        aggregate_failures do
          expect(invitation.client_agency_id).to eq(client_agency_id.to_s)
          expect(applicant.client_agency_id).to eq("la_ldh")
          expect(applicant.doc_id).to eq("ABC1234")
        end
      end

      it "returns the expected agency_partner_metadata" do
        create_invitation
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["agency_partner_metadata"]).to eq(
          "doc_id" => valid_params[:agency_partner_metadata][:doc_id],
          "case_number" => valid_params[:agency_partner_metadata][:case_number],
          "date_of_birth" => valid_params[:agency_partner_metadata][:date_of_birth],
        )
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        valid_params[:agency_partner_metadata].delete(:first_name)
        valid_params
      end

      it "returns unprocessable entity status" do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns structured error response" do
        post :create, params: invalid_params
        parsed_response = JSON.parse(response.body)
        aggregate_failures do
          expect(parsed_response).to have_key("errors")
          expect(parsed_response["errors"]).to be_an(Array)
        end
      end

      it "includes specific field errors" do
        post :create, params: invalid_params
        parsed_response = JSON.parse(response.body)
        error_fields = parsed_response["errors"].map { |e| e["field"] }
        aggregate_failures do
          expect(error_fields).not_to include("cbv_applicant")
          expect(error_fields).to include("cbv_applicant.first_name")
        end
      end
    end

    context "with params not included in the agency's valid attributes" do
      let(:params_with_invalid_attributes) do
        # client_id_number is only valid for certain agencies
        valid_params[:agency_partner_metadata][:client_id_number] = "1234567"
        valid_params
      end

      it "creates the invitation" do
        expect do
          post :create, params: params_with_invalid_attributes
        end.to change(CbvFlowInvitation, :count).by(1)
      end

      it "does not set the invalid attribute" do
        post :create, params: params_with_invalid_attributes
        invitation = CbvFlowInvitation.last
        expect(invitation.cbv_applicant.client_id_number).to be_nil
      end
    end

    context "with unauthorized user" do
      before do
        request.headers["Authorization"] = nil
      end

      it "returns unauthorized status" do
        post :create, params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns access denied message" do
        post :create, params: valid_params
        expect(response.body).to include("HTTP Token: Access denied.")
      end
    end

    context "with invalid language" do
      let(:invalid_user_params) do
        valid_params.merge(language: "zn")
      end

      it "returns unprocessable content status" do
        post :create, params: invalid_user_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns language field error" do
        post :create, params: invalid_user_params
        parsed_response = JSON.parse(response.body)
        aggregate_failures do
          expect(parsed_response).to have_key("errors")
          expect(parsed_response["errors"].map { |e| e["field"] }).to include("language")
        end
      end
    end
  end
end

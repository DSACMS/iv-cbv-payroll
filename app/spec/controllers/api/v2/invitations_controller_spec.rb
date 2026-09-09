require "rails_helper"

RSpec.describe Api::V2::InvitationsController do
  describe "#create" do
    subject(:make_request) do
      post :create, params: valid_params
    end

    let(:client_agency_id) { "sandbox".to_sym }
    let(:api_access_token_instance) do
      user = create(:user, :with_access_token, email: "test@test.com", client_agency_id: client_agency_id, is_service_account: true)
      user.api_access_tokens.first
    end

    let(:valid_params) do
      {
        language: "en",
        type: "community_engagement",
        agency_partner_metadata: {
          individual_id: "1234567",
          first_name: "John",
          last_name: "Smith",
          date_of_birth: "2000-01-01"
        }
      }
    end

    before do
      request.headers["Authorization"] = "Bearer #{api_access_token_instance.access_token}"
    end

    it "creates an activity flow invitation with an associated cbv_applicant" do
      expect { make_request }
        .to change(ActivityFlowInvitation, :count).by(1)
        .and change(CbvApplicant, :count).by(1)

      expect(response).to have_http_status(:created)
      parsed_response = JSON.parse(response.body)

      expect(parsed_response).to include("tokenized_url", "expiration_date", "language", "agency_partner_metadata")
      expect(parsed_response["tokenized_url"]).to include("activities/start")
      expect(parsed_response["language"]).to eq("en")
      expect(parsed_response["agency_partner_metadata"]).to eq(
        "individual_id" => "1234567",
        "first_name" => "John",
        "last_name" => "Smith",
        "date_of_birth" => "2000-01-01"
      )

      invitation = ActivityFlowInvitation.last
      expect(invitation.auth_token).to be_present
      expect(parsed_response["tokenized_url"]).to include(invitation.auth_token)
      expect(invitation.client_agency_id).to eq("sandbox")
      expect(invitation.user).to eq(api_access_token_instance.user)
      expect(invitation.language).to eq("en")
      expect(invitation.expires_at).to be_present

      applicant = invitation.cbv_applicant
      expect(applicant.first_name).to eq("John")
      expect(applicant.last_name).to eq("Smith")
      expect(applicant.date_of_birth).to eq(Date.new(2000, 1, 1))
      expect(applicant.individual_id).to eq("1234567")
      expect(applicant.client_agency_id).to eq("sandbox")
    end

    it "supports creating without individual_id" do
      params_without_individual_id = valid_params.deep_dup
      params_without_individual_id[:agency_partner_metadata].delete(:individual_id)

      expect {
        post :create, params: params_without_individual_id
      }.to change(ActivityFlowInvitation, :count).by(1)
        .and change(CbvApplicant, :count).by(1)

      expect(response).to have_http_status(:created)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response["agency_partner_metadata"]).to eq(
        "first_name" => "John",
        "last_name" => "Smith",
        "date_of_birth" => "2000-01-01"
      )

      applicant = ActivityFlowInvitation.last.cbv_applicant
      expect(applicant.individual_id).to be_nil
    end

    it "supports date_of_birth in MM/DD/YYYY format" do
      params_with_alt_dob = valid_params.deep_dup
      params_with_alt_dob[:agency_partner_metadata][:date_of_birth] = "01/15/2000"

      post :create, params: params_with_alt_dob

      expect(response).to have_http_status(:created)
      applicant = ActivityFlowInvitation.last.cbv_applicant
      expect(applicant.date_of_birth).to eq(Date.new(2000, 1, 15))
    end

    context "when caller belongs to LA LDH" do
      let(:client_agency_id) { "la_ldh".to_sym }

      it "creates CE invitation and applicant using LA LDH agency ID and domain" do
        expect { make_request }
          .to change(ActivityFlowInvitation, :count).by(1)
          .and change(CbvApplicant, :count).by(1)

        expect(response).to have_http_status(:created)
        invitation = ActivityFlowInvitation.last
        expect(invitation.client_agency_id).to eq("la_ldh")
        expect(invitation.cbv_applicant.client_agency_id).to eq("la_ldh")
      end
    end

    context "when caller belongs to Accenture" do
      let(:client_agency_id) { "accenture".to_sym }

      it "requires only CE metadata fields (first_name, last_name, date_of_birth) regardless of agency applicant attributes" do
        expect { make_request }
          .to change(ActivityFlowInvitation, :count).by(1)
          .and change(CbvApplicant, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "unauthorized user" do
      before do
        request.headers["Authorization"] = nil
      end

      it "returns unauthorized status" do
        post :create, params: valid_params

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include("HTTP Token: Access denied.")
      end
    end

    context "invalid type" do
      it "returns unprocessable entity when type is missing" do
        post :create, params: valid_params.except(:type)

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "type", "message" => "can't be blank" }
        )
      end

      it "returns unprocessable entity when type is income (out of scope for v2 currently)" do
        post :create, params: valid_params.merge(type: "income")

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "type", "message" => "must be community_engagement" }
        )
      end

      it "returns unprocessable entity when type is unsupported" do
        post :create, params: valid_params.merge(type: "unsupported_flow")

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "type", "message" => "must be community_engagement" }
        )
      end
    end

    context "invalid language" do
      it "returns unprocessable entity when language is not supported" do
        post :create, params: valid_params.merge(language: "fr")

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "language", "message" => "Language must be either English (en) or Spanish (es)." }
        )
      end
    end

    context "invalid agency_partner_metadata" do
      it "returns error when agency_partner_metadata is missing" do
        post :create, params: valid_params.except(:agency_partner_metadata)

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "agency_partner_metadata", "message" => "can't be blank" }
        )
      end

      it "returns error when first_name is missing" do
        invalid_params = valid_params.deep_dup
        invalid_params[:agency_partner_metadata].delete(:first_name)

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "agency_partner_metadata.first_name", "message" => "Enter the client's first name." }
        )
      end

      it "returns error when last_name is missing" do
        invalid_params = valid_params.deep_dup
        invalid_params[:agency_partner_metadata].delete(:last_name)

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "agency_partner_metadata.last_name", "message" => "Enter the client's last name." }
        )
      end

      it "returns error when date_of_birth is missing" do
        invalid_params = valid_params.deep_dup
        invalid_params[:agency_partner_metadata].delete(:date_of_birth)

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "agency_partner_metadata.date_of_birth", "message" => "Enter a valid date of birth" }
        )
      end

      it "returns error when date_of_birth is unparseable" do
        invalid_params = valid_params.deep_dup
        invalid_params[:agency_partner_metadata][:date_of_birth] = "not-a-valid-date"

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "agency_partner_metadata.date_of_birth", "message" => "Enter a valid date of birth" }
        )
      end

      it "returns error when date_of_birth is in the future" do
        invalid_params = valid_params.deep_dup
        invalid_params[:agency_partner_metadata][:date_of_birth] = 1.day.from_now.strftime("%Y-%m-%d")

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "agency_partner_metadata.date_of_birth", "message" => "Date of birth must be today or in the past" }
        )
      end

      it "returns error when date_of_birth is more than 110 years ago" do
        invalid_params = valid_params.deep_dup
        invalid_params[:agency_partner_metadata][:date_of_birth] = "1800-01-01"

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"]).to include(
          { "field" => "agency_partner_metadata.date_of_birth", "message" => "Enter a valid date of birth" }
        )
      end

      it "returns multiple errors simultaneously when multiple fields are invalid" do
        invalid_params = {
          type: "community_engagement",
          agency_partner_metadata: {
            individual_id: "1234567"
          }
        }

        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        error_fields = parsed_response["errors"].map { |e| e["field"] }

        expect(error_fields).to include(
          "agency_partner_metadata.first_name",
          "agency_partner_metadata.last_name",
          "agency_partner_metadata.date_of_birth"
        )
      end
    end
  end
end

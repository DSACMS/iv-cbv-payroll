require "rails_helper"

RSpec.describe Api::InvitationsController do
  describe "#create" do
    subject do
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


    it "creates an invitation with an associated cbv_applicant" do
      expect { subject }
        .to change(CbvFlowInvitation, :count).by(1)
        .and change(CbvApplicant, :count).by(1)

      expect(response).to have_http_status(:created)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to include("tokenized_url")
    end

    it "includes all agency_partner_metadata fields in the response" do
      subject
      parsed_response = JSON.parse(response.body)
      expect(parsed_response["agency_partner_metadata"].keys.map(&:to_sym)).to match_array(
        CbvApplicant.valid_attributes_for_agency(client_agency_id.to_s)
      )
    end

    it "creates an invitation using the client_agency_id in the access_token" do
      expect { subject }
        .to change(CbvFlowInvitation, :count).by(1)
        .and change(CbvApplicant, :count).by(1)

      invitation = CbvFlowInvitation.last
      expect(invitation.client_agency_id).to eq(client_agency_id.to_s)
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

      it "creates an invitation" do
        expect { subject }
          .to change(CbvFlowInvitation, :count).by(1)
          .and change(CbvApplicant, :count).by(1)

        invitation = CbvFlowInvitation.last
        expect(invitation.client_agency_id).to eq(client_agency_id.to_s)

        applicant = invitation.cbv_applicant
        expect(applicant.client_agency_id).to eq("la_ldh")
        expect(applicant.doc_id).to eq("ABC1234")
      end

      it "returns the expected agency_partner_metadata" do
        subject
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["agency_partner_metadata"]).to eq(
          "doc_id" => valid_params[:agency_partner_metadata][:doc_id],
          "case_number" => valid_params[:agency_partner_metadata][:case_number],
          "date_of_birth" => valid_params[:agency_partner_metadata][:date_of_birth],
        )
      end
    end

    context "invalid params" do
      let(:invalid_params) do
        valid_params[:agency_partner_metadata].delete(:first_name)
        valid_params
      end

      it "returns unprocessable entity with structured error response" do
        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)

        # Check for structured error response
        expect(parsed_response).to have_key("errors")
        expect(parsed_response["errors"]).to be_an(Array)

        # Extract error fields for easier testing
        error_fields = parsed_response["errors"].map { |e| e["field"] }

        expect(error_fields).not_to include("cbv_applicant")
        expect(error_fields).to include("cbv_applicant.first_name")
      end
    end

    context "params not included in the agency's valid attributes" do
      let(:params_with_invalid_attributes) do
        # client_id_number is only valid for certain agencies
        valid_params[:agency_partner_metadata][:client_id_number] = "1234567"
        valid_params
      end

      it "creates the invitation but does not set the invalid attribute" do
        expect do
          post :create, params: params_with_invalid_attributes
        end.to change(CbvFlowInvitation, :count).by(1)

        invitation = CbvFlowInvitation.last
        expect(invitation.cbv_applicant.client_id_number).to be_nil
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

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to have_key("errors")
        expect(parsed_response["errors"].map { |e| e["field"] }).to include("language")
      end
    end

    context "with pre-populated volunteering activities" do
      let(:volunteering_entry) do
        {
          type: "volunteering",
          organization_name: "Red Cross",
          street_address: "123 Main St",
          city: "Boston",
          state: "MA",
          zip_code: "02101",
          coordinator_name: "Pat Smith",
          coordinator_email: "pat@redcross.org",
          coordinator_phone_number: "555-0100"
        }
      end
      let(:params_with_activities) { valid_params.merge(activities: [ volunteering_entry ]) }

      it "mints both invitations and returns activity_tokenized_url" do
        expect {
          post :create, params: params_with_activities
        }.to change(CbvFlowInvitation, :count).by(1)
          .and change(ActivityFlowInvitation, :count).by(1)

        expect(response).to have_http_status(:created)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to include("tokenized_url", "activity_tokenized_url")
        expect(parsed_response["activity_tokenized_url"]).to include("activities/start")

        activity_invitation = ActivityFlowInvitation.last
        expect(activity_invitation.cbv_applicant).to eq(CbvFlowInvitation.last.cbv_applicant)
        expect(activity_invitation.pre_populated_activities.length).to eq(1)
        expect(activity_invitation.pre_populated_activities.first["organization_name"]).to eq("Red Cross")
      end

      it "returns errors when an activity entry is missing organization_name" do
        invalid_entry = volunteering_entry.except(:organization_name)

        post :create, params: valid_params.merge(activities: [ invalid_entry ])

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"].map { |e| e["field"] })
          .to include("activities[0].organization_name")
      end

      it "returns errors for unsupported activity types" do
        post :create, params: valid_params.merge(activities: [ volunteering_entry.merge(type: "knitting") ])

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"].map { |e| e["field"] })
          .to include("activities[0].type")
      end

      it "rejects month dates outside the reporting window" do
        out_of_window = (Date.current + 60.days).iso8601
        entry_with_bad_month = volunteering_entry.merge(
          months: [ { month: out_of_window, hours: 4 } ]
        )

        post :create, params: valid_params.merge(activities: [ entry_with_bad_month ])

        expect(response).to have_http_status(:unprocessable_content)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["errors"].map { |e| e["field"] })
          .to include("activities[0].months[0].month")
      end

      it "persists pre-populated monthly hours on the activity invitation" do
        in_window = ActivityFlow.expected_reporting_window_range("sandbox").end.beginning_of_month.iso8601
        entry_with_months = volunteering_entry.merge(
          months: [ { month: in_window, hours: 10 } ]
        )

        post :create, params: valid_params.merge(activities: [ entry_with_months ])

        expect(response).to have_http_status(:created)
        invitation = ActivityFlowInvitation.last
        persisted_months = invitation.pre_populated_activities.first["months"]
        expect(persisted_months.length).to eq(1)
        expect(persisted_months.map { |m| m["hours"].to_i }).to eq([ 10 ])
      end

      context "when prefilled_activities_enabled is false for the agency" do
        before do
          stub_client_agency_config_value("sandbox", :prefilled_activities_enabled, false)
        end

        it "ignores activities, mints only the cbv invitation, and omits activity_tokenized_url" do
          expect {
            post :create, params: params_with_activities
          }.to change(CbvFlowInvitation, :count).by(1)
            .and not_change(ActivityFlowInvitation, :count)

          expect(response).to have_http_status(:created)
          parsed_response = JSON.parse(response.body)
          expect(parsed_response).to include("tokenized_url")
          expect(parsed_response).not_to have_key("activity_tokenized_url")
        end
      end
    end
  end
end

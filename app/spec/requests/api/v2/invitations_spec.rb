require "swagger_helper"

RSpec.describe "Tokenized Link API V2", type: :request do
  let(:agency_id) { "sandbox" }
  let(:user) { create(:user, :with_access_token, client_agency_id: agency_id, is_service_account: true) }
  let(:authorization) { "Bearer #{user.api_access_tokens.first.access_token}" }
  let(:Authorization) { authorization } # rubocop:disable RSpec/VariableName -- rswag uses the HTTP header name.
  let(:invitation_type) { "employment" }
  let(:invitation) do
    {
      language: "en",
      verification_range: "last_complete_month",
      agency_partner_metadata: {
        individual_id: "INDIVIDUAL-123",
        first_name: "Jane", last_name: "Doe", case_number: "EXAMPLE-123", date_of_birth: "01/15/1990"
      }
    }
  end

  around do |example|
    ClimateControl.modify(DOMAIN_NAME: "verify-demo.navapbc.cloud") do
      Timecop.freeze(Time.utc(2026, 9, 23, 12)) { example.run }
    end
  end

  before do
    stub_client_agency_config_value(agency_id, :agency_domain, "verify-demo.navapbc.cloud")
    allow(Rails.application.routes).to receive(:default_url_options).and_return(
      Rails.application.routes.default_url_options.merge(protocol: "https")
    )
    allow(CbvFlowInvitation).to receive(:generate_unique_secure_token).and_return("IncomeExampleToken")
  end

  path "/api/v2/{invitation_type}/invitations" do
    parameter name: :invitation_type, in: :path, schema: {
      type: :string, enum: [ "community-engagement", "employment" ]
    }, description: "Selects which activity flow is created alongside the income invitation."

    post "Create tokenized reporting links, with an activity invitation" do
      tags "Invitations"
      operationId "createInvitationV2"
      description InvitationDocumentation.read("post-v2-invitations", section: "Description")
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :invitation, in: :body, required: true, schema: { "$ref" => "#/components/schemas/V2InvitationRequest" }

      response "201", "Invitations created" do
        schema "$ref" => "#/components/schemas/V2InvitationResponse"

        context "with invitation_type employment" do
          let(:invitation_type) { "employment" }

          run_test! "creates an income link and an activity link", example_summary: "Employment invitation (sandbox agency)", openapi_example: :employment do
            expect(response.parsed_body).to have_key("activity_tokenized_url")
            expect(CbvFlowInvitation.last.client_agency_id).to eq(agency_id)
          end
        end

        context "with invitation_type community-engagement" do
          let(:invitation_type) { "community-engagement" }

          run_test! "creates an income link and a community engagement activity link", example_summary: "Community engagement invitation (sandbox agency)", openapi_example: :community_engagement do
            expect(response.parsed_body).to have_key("activity_tokenized_url")
          end
        end
      end

      response "401", "Missing or invalid API key (plain text, not JSON)" do
        metadata[:response][:content] = { "text/plain" => { schema: { type: :string } } }
        header "WWW-Authenticate", schema: { type: :string }
        let(:authorization) { nil }

        run_test! "rejects a missing key" do
          expect(response.media_type).to eq("text/plain")
        end
      end

      response "422", "Validation failed" do
        schema "$ref" => "#/components/schemas/V2InvitationErrors"

        context "without a required applicant name" do
          let(:invitation) { super().deep_merge(agency_partner_metadata: { first_name: nil }) }

          run_test! "returns applicant errors", example_summary: "Missing applicant name", openapi_example: :missing_name do
            expect(response.parsed_body["errors"].pluck("field")).to include("first_name")
          end
        end
      end
    end
  end
end

require "swagger_helper"

RSpec.describe "Tokenized Link API", type: :request do
  let(:agency_id) { "sandbox" }
  let(:user) { create(:user, :with_access_token, client_agency_id: agency_id, is_service_account: true) }
  let(:authorization) { "Bearer #{user.api_access_tokens.first.access_token}" }
  let(:Authorization) { authorization } # rubocop:disable RSpec/VariableName -- rswag uses the HTTP header name.
  let(:invitation) do
    {
      language: "en",
      agency_partner_metadata: {
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
    # Match production's HTTPS URL defaults without depending on local settings.
    allow(Rails.application.routes).to receive(:default_url_options).and_return(
      Rails.application.routes.default_url_options.merge(protocol: "https")
    )
    # Only replace random tokens: the requests still create and validate records.
    allow(CbvFlowInvitation).to receive(:generate_unique_secure_token).and_return("IncomeExampleToken")
    allow(ActivityFlowInvitation).to receive(:generate_unique_secure_token).and_return("ActivityExampleToken")
  end

  path "/api/v1/invitations" do
    post "Create tokenized reporting links" do
      tags "Invitations"
      operationId "createInvitation"
      description InvitationDocumentation::CREATE_INVITATION
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :invitation, in: :body, required: true, schema: { "$ref" => "#/components/schemas/InvitationRequest" }

      response "201", "Invitations created" do
        schema "$ref" => "#/components/schemas/InvitationResponse"

        context "with income only" do
          run_test! "creates an income link", example_summary: "Income invitation (sandbox agency)", openapi_example: :income do
            expect(response.parsed_body).not_to have_key("activity_tokenized_url")
            expect(response.parsed_body["agency_partner_metadata"]["middle_name"]).to be_nil
            expect(CbvFlowInvitation.last.client_agency_id).to eq(agency_id)
            expect(ActionMailer::Base.deliveries).to be_empty
          end
        end

        context "with Spanish language" do
          let(:invitation) { super().merge(language: "es") }

          run_test! "creates a Spanish link", example_summary: "Spanish invitation", openapi_example: :spanish do
            expect(response.parsed_body["language"]).to eq("es")
            expect(response.parsed_body["tokenized_url"]).to include("/es/start/")
          end
        end

        context "with Louisiana metadata" do
          let(:agency_id) { "la_ldh" }
          let(:invitation) { { language: "en", agency_partner_metadata: { doc_id: "EXAMPLE-DOC-123", date_of_birth: "01/15/1990" } } }

          run_test! "returns the agency's metadata fields", example_summary: "Louisiana indexing metadata", openapi_example: :louisiana do
            expect(response.parsed_body["agency_partner_metadata"]).to eq(invitation[:agency_partner_metadata].stringify_keys.merge("case_number" => nil))
            expect(response.parsed_body["expiration_date"]).to start_with("2026-12-07T23:59:59")
          end
        end

        {
          volunteering: { organization_name: "Example Food Bank", coordinator_email: "coordinator@example.org", months: [ { month: "2026-08-01", hours: 12.5 } ] },
          employment: { employer_name: "Example Employer", is_self_employed: false, months: [ { month: "2026-08-01", hours: 80, gross_income: 1250.50 } ] },
          education: { school_name: "Example Community College", months: [ { month: "2026-08-01", hours: 6 } ] },
          job_training: { program_name: "Example Training Program", organization_name: "Example Training Center", months: [ { month: "2026-08-01", hours: 20 } ] }
        }.each do |type, attributes|
          context "with #{type} activities" do
            let(:invitation) { super().merge(activities: [ attributes.merge(type: type.to_s) ]) }

            run_test! "creates both links" do
              expect(response.parsed_body["activity_tokenized_url"]).to include("/activities/start/")
              expect(ActivityFlowInvitation.last.pre_populated_activities).to eq(invitation[:activities].map(&:deep_stringify_keys))
            end
          end
        end

        context "with activities disabled" do
          let(:invitation) { super().merge(activities: [ { type: "volunteering", organization_name: "Example Food Bank" } ]) }

          before { stub_client_agency_config_value(agency_id, :prefilled_activities_enabled, false) }

          run_test! "ignores activities" do
            expect(response.parsed_body).not_to have_key("activity_tokenized_url")
            expect(ActivityFlowInvitation.count).to eq(0)
          end
        end

        context "with an empty activities list" do
          let(:invitation) { super().merge(activities: []) }

          run_test! do
            expect(response.parsed_body).not_to have_key("activity_tokenized_url")
          end
        end

        context "with unrecognized metadata" do
          let(:invitation) { super().deep_merge(agency_partner_metadata: { individual_id: "ignored", unknown_field: "ignored" }) }

          run_test! do
            expect(response.parsed_body["agency_partner_metadata"]).not_to include("individual_id", "unknown_field")
          end
        end
      end

      response "401", "Missing or invalid API key (plain text, not JSON)" do
        # Rails' HTTP token authentication returns plain text even for a JSON request.
        metadata[:response][:content] = { "text/plain" => { schema: { type: :string } } }
        header "WWW-Authenticate", schema: { type: :string }
        let(:authorization) { nil }

        context "without a key" do
          run_test! "rejects a missing key", example_summary: "Authentication failure", openapi_example: :unauthorized do
            expect(response.media_type).to eq("text/plain")
            expect(response.body).to eq("HTTP Token: Access denied.\n")
          end
        end

        context "with an invalid key" do
          let(:authorization) { "Bearer invalid-example-key" }

          run_test!
        end
      end

      response "422", "Validation failed" do
        schema "$ref" => "#/components/schemas/InvitationErrors"

        context "with an unsupported language" do
          let(:invitation) { super().merge(language: "zz") }

          run_test! "rejects the language", example_summary: "Unsupported language", openapi_example: :invalid_language do
            expect(response.parsed_body["errors"].pluck("field")).to include("language")
          end
        end

        context "without a language" do
          let(:invitation) { super().except(:language) }

          run_test! do
            expect(response.parsed_body["errors"].pluck("field")).to include("language")
          end
        end

        context "without a required applicant name" do
          let(:invitation) { super().deep_merge(agency_partner_metadata: { first_name: nil }) }

          run_test! "returns applicant errors", example_summary: "Missing applicant name", openapi_example: :missing_name do
            expect(response.parsed_body["errors"].pluck("field")).to include("cbv_applicant.first_name")
          end
        end

        context "without a required activity field" do
          let(:invitation) { super().merge(activities: [ { type: "volunteering" } ]) }

          run_test! "returns an indexed activity error" do
            expect(response.parsed_body["errors"].pluck("field")).to include("activities[0].organization_name")
            expect(CbvFlowInvitation.count).to eq(1)
            expect(ActivityFlowInvitation.count).to eq(0)
          end
        end

        context "with an unsupported activity type" do
          let(:invitation) { super().merge(activities: [ { type: "unsupported" } ]) }

          run_test! "rejects the type" do
            expect(response.parsed_body["errors"].pluck("field")).to include("activities[0].type")
          end
        end

        context "with a month outside the reporting window" do
          let(:invitation) { super().merge(activities: [ { type: "volunteering", organization_name: "Example Food Bank", months: [ { month: "2026-10-01", hours: 10 } ] } ]) }

          run_test! "rejects the month" do
            expect(response.parsed_body["errors"].pluck("field")).to include("activities[0].months[0].month")
          end
        end
      end
    end
  end
end

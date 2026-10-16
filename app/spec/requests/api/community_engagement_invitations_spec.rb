require "swagger_helper"

RSpec.describe "Community engagement invitations API", type: :request do
  let(:user) { create(:user, :with_access_token, client_agency_id: "sandbox", is_service_account: true) }
  let(:Authorization) { "Bearer #{user.api_access_tokens.first.access_token}" } # rubocop:disable RSpec/VariableName -- rswag uses the HTTP header name.
  let(:invitation) do
    {
      language: "en",
      verification_range: "last_complete_month",
      agency_partner_metadata: {
        individual_id: "EXAMPLE-123", first_name: "Jane", last_name: "Doe", date_of_birth: "1990-01-15"
      }
    }
  end

  around do |example|
    ClimateControl.modify(DOMAIN_NAME: "verify-demo.navapbc.cloud") do
      Timecop.freeze(Time.utc(2026, 9, 23, 12)) { example.run }
    end
  end

  before do
    stub_client_agency_config_value("sandbox", :agency_domain, "verify-demo.navapbc.cloud")
    allow(Rails.application.routes).to receive(:default_url_options).and_return(
      Rails.application.routes.default_url_options.merge(protocol: "https")
    )
    allow(CbvFlowInvitation).to receive(:generate_unique_secure_token).and_return("IncomeExampleToken")
    allow(ActivityFlowInvitation).to receive(:generate_unique_secure_token).and_return("ActivityExampleToken")
  end

  path "/api/v2/community-engagement/invitations" do
    post "Create community engagement reporting links" do
      tags "Invitations"
      operationId "createCommunityEngagementInvitation"
      description "Create a community engagement invitation. Set unpaid_work_only to true to limit employment reporting to unpaid work; null, false, and omission leave employment unrestricted."
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :invitation, in: :body, required: true, schema: { "$ref" => "#/components/schemas/CommunityEngagementInvitationRequest" }

      response "201", "Invitations created" do
        schema "$ref" => "#/components/schemas/CommunityEngagementInvitationResponse"

        context "with standard community engagement" do
          run_test! "creates a CE invitation", example_summary: "Community engagement invitation", openapi_example: :community_engagement do
            expect(ActivityFlowInvitation.last).not_to be_unpaid_work_only
          end
        end

        context "with unpaid-only employment" do
          let(:invitation) { super().merge(unpaid_work_only: true) }

          run_test! "creates an unpaid-only CE flow", example_summary: "Community engagement with unpaid work only", openapi_example: :unpaid_work_only do
            activity_invitation = ActivityFlowInvitation.last
            expect(response.parsed_body.fetch("activity_tokenized_url")).to include(activity_invitation.auth_token)
            expect(ActivityFlow.create_from_invitation(activity_invitation, "example-device")).to be_unpaid_work_only
          end
        end

        context "with a null restriction" do
          let(:invitation) { super().merge(unpaid_work_only: nil) }

          run_test! "stores null without restricting employment" do
            expect(ActivityFlowInvitation.last.unpaid_work_only).to be_nil
          end
        end
      end

      response "422", "Invalid unpaid-work restriction or invitation fields" do
        schema "$ref" => "#/components/schemas/InvitationErrors"
        let(:invitation) { super().merge(unpaid_work_only: "true") }

        run_test! do
          expect(response.parsed_body.fetch("errors").pluck("field")).to include("unpaid_work_only")
        end
      end
    end
  end
end

RSpec.shared_context "activity_hub" do
  before do
    stub_const("Aggregators::Sdk::NscService::ENVIRONMENTS", {
      test: {
        base_url: ENV.fetch("NSC_API_URL_TEST", "https://verify.demo.studentclearinghouse.org/api/vs-ext-test"),
        token_url: ENV.fetch("NSC_TOKEN_URL_TEST", "https://id.demo.studentclearinghouse.org/oauth2/ausnsnbp1duL7tEPi0h7/v1/token"),
        client_id: ENV.fetch("NSC_CLIENT_ID_TEST", "123"),
        client_secret: ENV.fetch("NSC_CLIENT_SECRET_TEST", "top-secret"),
        account_id: ENV.fetch("NSC_ACCOUNT_ID_TEST", "456"),
        scope: "vs.api.insights"
      }
    })
    stub_fdsh_no_enrollment_response
  end

  def stub_fdsh_no_enrollment_response
    # The E2E VCR recording predates the FDSH integration. Stub the Hub token
    # and an empty NSC result so tests never call the live Hub.
    stub_request(:post, %r{/auth/oauth/v2/token\z})
      .to_return(status: 200, body: { access_token: "e2e-hub-token", expires_in: 3600 }.to_json)
    stub_request(:post, %r{/mesh/imp1/NationalStudentClearinghouseService\z})
      .to_return(
        status: 200,
        body: {
          nscResponse: {
            transactionDetails: { nscHit: "N" },
            studentInfoProvided: { personGivenName: "Test", personSurName: "Student" },
            enrollmentDetails: []
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  around do |example|
    stub_environment_variables({
      "ACTIVITY_HUB_ENABLED" => "true",
      "NSC_ENVIRONMENT" => "test"
    }, &example)
  end
end

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
  end

  around do |example|
    stub_environment_variables({
      "ACTIVITY_HUB_ENABLED" => "true",
      "NSC_ENVIRONMENT" => "test"
    }, &example)
  end
end

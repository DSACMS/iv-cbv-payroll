require 'rails_helper'

RSpec.describe Aggregators::Sdk::NscService, type: :service do
  subject(:service) { described_class.new }

  let(:http_client) { instance_double(Faraday::Connection) }
  let(:params) do
    {
      first_name: "John",
      last_name: "Doe",
      date_of_birth: "1990-01-01"
    }
  end

  let(:unauthorized_response) { instance_double(Faraday::Response, status: 401, body: '{}') }
  let(:success_response) do
    instance_double(
      Faraday::Response,
      status: 200,
      body: '{"transactionDetails": {}}'
    )
  end

  before do
    # Stub HTTP client to return 401 first, then success
    allow(service).to receive(:http_client).and_return(http_client)
    allow(http_client).to receive(:post).and_return(unauthorized_response, success_response)

    # Stub cache delete so we can track it
    allow(Rails.cache).to receive(:delete)
  end

  it "retries once after unauthorized and caches token correctly" do
    # Call the service
    result = service.fetch_enrollment_data(**params)

    # Check the result
    expect(JSON.parse(result)).to eq("transactionDetails" => {})

    # Assertions on cache and retry
    expect(Rails.cache).to have_received(:delete).once # cache deleted on 401
    expect(http_client).to have_received(:post).twice  # HTTP post retried
  end
end

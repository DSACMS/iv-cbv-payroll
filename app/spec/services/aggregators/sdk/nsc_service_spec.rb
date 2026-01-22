require 'rails_helper'
RSpec.describe Aggregators::Sdk::NscService, type: :service do
  subject(:service) { described_class.new }

  let(:http_client) { instance_double(Faraday::Connection) }

  let(:user_linda) do
    {
      first_name: "Linda",
      last_name: "Cooper",
      date_of_birth: "1999-01-01"
    }
  end

  let(:user_lynette) do
    {
      first_name: "Lynnette",
      last_name: "Oyola",
      date_of_birth: "1988-10-24"
    }
  end

  describe 'token retry on unauthorized response' do
    let(:unauthorized_response) do
      instance_double(Faraday::Response, status: 401, body: '{}')
    end

    let(:success_response) do
      instance_double(
        Faraday::Response,
        status: 200,
        body: '{"transactionDetails": {}}'
      )
    end

    before do
      allow(service).to receive(:http_client).and_return(http_client)
      allow(http_client).to receive(:post)
        .and_return(unauthorized_response, success_response)

      allow(Rails.cache).to receive(:delete)
    end

    it 'retries once after unauthorized and clears cached token' do
      result = service.fetch_enrollment_data(**user_linda)

      expect(JSON.parse(result)).to eq("transactionDetails" => {})
      expect(Rails.cache).to have_received(:delete).once
      expect(http_client).to have_received(:post).twice
    end
  end

  xdescribe 'fetch_enrollment_data' do
    let(:requests) do
      WebMock::RequestRegistry.instance.requested_signatures.hash.keys
    end

    it 'returns response with enrollmentDetails for found student' do
      nsc_stub_request_education_search_response("lynette")

      response = service.fetch_enrollment_data(**user_lynette)

      expect(response).to have_key(:studentInfoProvided)
      expect(response).to have_key(:enrollmentDetails)
    end

    it 'returns limited response for not-found student' do
      nsc_stub_request_education_search_response("linda")

      response = service.fetch_enrollment_data(**user_linda)

      expect(response).to have_key(:studentInfoProvided)
      expect(response).not_to have_key(:enrollmentDetails)
    end

    it 'raises Faraday::ServerError on 500 error' do
      stub_request(:get, Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT)
        .to_return(status: 500, body: "", headers: {})

      expect { service.fetch_enrollment_data(**user_linda) }
        .to raise_error(Faraday::ServerError)
    end
  end
end

require 'rails_helper'

RSpec.describe Aggregators::Sdk::NscService, type: :service do
  subject(:service) { described_class.new(environment: :test, logger: logger) }

  let(:logger) { Logger.new(StringIO.new) }

  before do
    stub_const("Aggregators::Sdk::NscService::ENVIRONMENTS", {
      test: {
        base_url: "http://fake-nsc-api.local",
        token_url: "http://fake-nsc-api.local/token",
        client_id: "123",
        client_secret: "top-secret",
        account_id: "456",
        scope: "vs.api.insights"
      }
    })
  end

  describe "#fetch_enrollment_data" do
    let!(:token_request_stub) do
      nsc_stub_token_request
    end

    context "for Lynette, a user with enrollment details" do
      before do
        nsc_stub_request_education_search_response("lynette")
      end

      let(:user_lynette) do
        {
          first_name: "Lynnette",
          last_name: "Oyola",
          date_of_birth: "1988-10-24"
        }
      end

      it "returns response with enrollmentDetails for found student" do
        response = service.fetch_enrollment_data(**user_lynette)

        expect(response).to have_key("studentInfoProvided")
        expect(response).to have_key("enrollmentDetails")
      end

      context "when the OAuth token is expired" do
        let!(:education_search_stub) do
          nsc_stub_request_education_search_token_expired_response("lynette")
        end

        it "retries once after unauthorized and clears cached token" do
          result = service.fetch_enrollment_data(**user_lynette)

          expect(result).to include("transactionDetails")
          expect(token_request_stub).to have_been_requested
          expect(education_search_stub).to have_been_requested.twice
        end
      end

      context "when the server returns a 500 error" do
        it "raises an ApiError" do
          stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
            .to_return(status: 500, body: "", headers: {})

          expect { service.fetch_enrollment_data(**user_lynette) }
            .to raise_error(Aggregators::Sdk::NscService::ApiError)
        end
      end
    end

    context "for Linda, a user with no enrollment result" do
      before do
        nsc_stub_request_education_search_response("linda")
      end

      let(:user_linda) do
        {
          first_name: "Linda",
          last_name: "Cooper",
          date_of_birth: "1999-01-01"
        }
      end

      it "returns a response without enrollmentDetails" do
        response = service.fetch_enrollment_data(**user_linda)

        expect(response).to have_key("studentInfoProvided")
        expect(response).not_to have_key("enrollmentDetails")
      end
    end
  end
end

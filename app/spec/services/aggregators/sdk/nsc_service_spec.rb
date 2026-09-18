# frozen_string_literal: true

require "rails_helper"

RSpec.describe Aggregators::Sdk::NscService, type: :service do
  subject(:service) { described_class.new(environment: :test, logger: test_logger) }

  let(:log_output) { StringIO.new }
  let(:test_logger) { Logger.new(log_output) }

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

    allow(NewRelic::Agent).to receive(:record_metric)
    allow(NewRelic::Agent).to receive(:record_custom_event)
    allow(NewRelic::Agent).to receive(:notice_error)
  end

  describe "#fetch_enrollment_data" do
    let!(:token_request_stub) do
      nsc_stub_token_request
    end

    let(:user_lynette) do
      {
        first_name: "Lynnette",
        last_name: "Oyola",
        date_of_birth: "1988-10-24",
        as_of_date: Date.today
      }
    end

    context "for Lynette, a user with enrollment details" do
      before do
        nsc_stub_request_education_search_response("lynette")
      end

      it "returns response with enrollmentDetails for found student and records success telemetry" do
        response = service.fetch_enrollment_data(**user_lynette)

        expect(response).to have_key("studentInfoProvided")
        expect(response).to have_key("enrollmentDetails")
        expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/NSC/Calls", 1).at_least(:once)
        expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/NSC/Success", 1).at_least(:once)
        expect(NewRelic::Agent).to have_received(:record_custom_event).with("NscApiCall", hash_including(status: "success")).at_least(:once)
      end

      context "when the OAuth token is expired" do
        let!(:education_search_stub) do
          nsc_stub_request_education_search_token_expired_response("lynette")
        end

        it "retries once after unauthorized" do
          result = service.fetch_enrollment_data(**user_lynette)

          expect(result).to include("transactionDetails")
          expect(token_request_stub).to have_been_requested
          expect(education_search_stub).to have_been_requested.twice
        end
      end

      context "when the server returns a 500 error" do
        it "raises a ServerError, classifies as hub-side, logs failure details, and emits telemetry" do
          stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
            .to_return(status: 500, body: '{"error": "Internal server error"}', headers: { "Content-Type" => "application/json" })

          expect { service.fetch_enrollment_data(**user_lynette) }
            .to raise_error(Aggregators::Sdk::NscService::ServerError) do |e|
              expect(e.hub_side?).to be true
              expect(e.application_side?).to be false
              expect(e.status).to eq(500)
              expect(e.error_type).to eq(:server_error)
            end

          expect(log_output.string).to include("[NSC/Hub Failure]")
          expect(log_output.string).to include("origin=hub")
          expect(log_output.string).to include("type=server_error")
          expect(log_output.string).to include('classification="Hub-side"')
          expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/NSC/Failure", 1)
          expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/NSC/Failure/hub", 1)
          expect(NewRelic::Agent).to have_received(:record_custom_event).with("NscApiFailure", hash_including(
            failure_origin: "hub",
            error_type: "server_error",
            status_code: 500
          ))
        end
      end

      context "when a timeout occurs during request" do
        it "raises a TimeoutError, classifies as hub-side, and records telemetry" do
          stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
            .to_timeout

          expect { service.fetch_enrollment_data(**user_lynette) }
            .to raise_error(Aggregators::Sdk::NscService::TimeoutError) do |e|
              expect(e.hub_side?).to be true
              expect(e.timeout?).to be true
              expect(e.error_type).to eq(:timeout)
            end

          expect(log_output.string).to include("[NSC/Hub Failure]")
          expect(log_output.string).to include("type=timeout")
          expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/NSC/Failure/timeout", 1)
          expect(NewRelic::Agent).to have_received(:notice_error).with(
            instance_of(Aggregators::Sdk::NscService::TimeoutError),
            hash_including(custom_params: hash_including(failure_origin: :hub, error_type: :timeout))
          )
        end
      end

      context "when a connection failure occurs" do
        it "raises a ConnectionError, classifies as hub-side, and records telemetry" do
          stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
            .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

          expect { service.fetch_enrollment_data(**user_lynette) }
            .to raise_error(Aggregators::Sdk::NscService::ConnectionError) do |e|
              expect(e.hub_side?).to be true
              expect(e.connection_error?).to be true
              expect(e.error_type).to eq(:connection_error)
            end

          expect(log_output.string).to include("[NSC/Hub Failure]")
          expect(log_output.string).to include("type=connection_error")
          expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/NSC/Failure/connection_error", 1)
        end
      end

      context "when a TLS/SSL error occurs" do
        it "raises a TlsCertError, classifies as TLS origin, and records telemetry" do
          stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
            .to_raise(Faraday::SSLError.new("SSL_connect returned=1 errno=0 peerref=... certificate verify failed"))

          expect { service.fetch_enrollment_data(**user_lynette) }
            .to raise_error(Aggregators::Sdk::NscService::TlsCertError) do |e|
              expect(e.tls_cert_error?).to be true
              expect(e.failure_origin).to eq(:tls)
              expect(e.error_type).to eq(:tls_cert_error)
            end

          expect(log_output.string).to include("[NSC/Hub Failure]")
          expect(log_output.string).to include("origin=tls")
          expect(log_output.string).to include('classification="TLS/Cert"')
          expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/NSC/Failure/tls", 1)
        end
      end

      context "when the API returns a 429 Rate Limit" do
        it "raises RateLimitError, classifies as hub-side, and records telemetry" do
          stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
            .to_return(status: 429, body: '{"code": "RATE_LIMITED", "message": "Too many requests"}')

          expect { service.fetch_enrollment_data(**user_lynette) }
            .to raise_error(Aggregators::Sdk::NscService::RateLimitError) do |e|
              expect(e.hub_side?).to be true
              expect(e.status).to eq(429)
              expect(e.error_type).to eq(:rate_limit)
            end

          expect(log_output.string).to include("type=rate_limit")
          expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/NSC/Failure/rate_limit", 1)
        end
      end

      context "when the API returns a 400 Bad Request" do
        it "raises ClientError, classifies as application-side, and records telemetry" do
          stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
            .to_return(status: 400, body: '{"code": "INVALID_PARAMS", "message": "Missing required field"}')

          expect { service.fetch_enrollment_data(**user_lynette) }
            .to raise_error(Aggregators::Sdk::NscService::ClientError) do |e|
              expect(e.application_side?).to be true
              expect(e.hub_side?).to be false
              expect(e.status).to eq(400)
              expect(e.error_type).to eq(:client_error)
            end

          expect(log_output.string).to include("origin=application")
          expect(log_output.string).to include('classification="Application-side"')
          expect(NewRelic::Agent).to have_received(:record_metric).with("Custom/NSC/Failure/application", 1)
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
          date_of_birth: "1999-01-01",
          as_of_date: Date.today
        }
      end

      it "returns a response without enrollmentDetails" do
        response = service.fetch_enrollment_data(**user_linda)

        expect(response).to have_key("studentInfoProvided")
        expect(response).not_to have_key("enrollmentDetails")
      end
    end
  end

  describe "#fetch_oauth_token" do
    context "when token URL is missing" do
      before do
        stub_const("Aggregators::Sdk::NscService::ENVIRONMENTS", {
          test: {
            base_url: "http://fake-nsc-api.local",
            token_url: nil,
            client_id: "123",
            client_secret: "top-secret"
          }
        })
      end

      it "raises ConfigurationError classified as application-side" do
        expect { service.fetch_oauth_token }
          .to raise_error(Aggregators::Sdk::NscService::ConfigurationError) do |e|
            expect(e.application_side?).to be true
            expect(e.code).to eq("MISSING_TOKEN_URL")
          end
      end
    end

    context "when token endpoint returns 503 Service Unavailable" do
      it "raises ServerError classified as hub-side" do
        stub_request(:post, %r{/token})
          .to_return(status: 503, body: "Service Unavailable")

        expect { service.fetch_oauth_token }
          .to raise_error(Aggregators::Sdk::NscService::ServerError) do |e|
            expect(e.hub_side?).to be true
            expect(e.status).to eq(503)
          end
      end
    end
  end
end

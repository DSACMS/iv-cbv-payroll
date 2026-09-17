require "rails_helper"

RSpec.describe Aggregators::Sdk::NscFdshService, type: :service do
  subject(:service) do
    described_class.new(
      base_url: base_url,
      token_url: token_url,
      education_enrollment_url: education_enrollment_url,
      client_id: "client-id",
      client_secret: "client-secret",
      client_cert: certificate,
      client_key: private_key,
      logger: logger
    )
  end

  let(:base_url) { "https://impl.hub.cms.gov:8443" }
  let(:token_url) { "#{base_url}/auth/oauth/v2/token" }
  let(:education_enrollment_url) { "mesh/imp1/NationalStudentClearinghouseService" }
  let(:logger) { Logger.new(StringIO.new) }
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:certificate) do
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = 1
    certificate.subject = OpenSSL::X509::Name.parse("/CN=impl.hub.cms.gov")
    certificate.issuer = certificate.subject
    certificate.public_key = private_key.public_key
    certificate.not_before = Time.now
    certificate.not_after = 1.day.from_now
    certificate.sign(private_key, OpenSSL::Digest::SHA256.new)
    certificate
  end

  let(:token_response) do
    {
      access_token: "hub-access-token",
      token_type: "Bearer",
      expires_in: 3600
    }
  end

  let(:fdsh_response) do
    {
      nscResponse: {
        studentInfoProvided: {
          personGivenName: "Lynnette",
          personSurName: "Oyola",
          personBirthDate: "1988-10-24"
        },
        enrollmentDetails: [
          {
            officialSchoolName: "Trident University International",
            schoolCode: "123456",
            currentEnrollmentStatusCode: "CC",
            enrollmentData: [
              {
                enrollmentStatusCode: "Y",
                termBeginDate: "2024-05-31",
                termEndDate: "2024-11-19"
              }
            ]
          }
        ]
      }
    }
  end

  before do
    stub_request(:post, token_url)
      .to_return(status: 200, body: token_response.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe "#fetch_enrollment_data" do
    it "requests enrollment data through the Hub and preserves the existing response shape" do
      stub_request(:post, "#{base_url}/#{education_enrollment_url}")
        .to_return(status: 200, body: fdsh_response.to_json, headers: { "Content-Type" => "application/json" })

      allow(logger).to receive(:info).and_call_original
      expect(logger).to receive(:info).with("Requesting FDSH OAuth token from impl.hub.cms.gov:8443/auth/oauth/v2/token")
        .and_call_original
      expect(logger).to receive(:info).with(
        "FDSH POST request to impl.hub.cms.gov:8443/auth/oauth/v2/token returned HTTP 200"
      ).and_call_original
      expect(logger).to receive(:info).with("Received FDSH OAuth access token (expires_in=3600 seconds)")
        .and_call_original
      expect(logger).to receive(:info).with(
        "Requesting FDSH NSC enrollment data from impl.hub.cms.gov:8443/mesh/imp1/NationalStudentClearinghouseService"
      ).and_call_original
      expect(logger).to receive(:info).with(
        "FDSH POST request to impl.hub.cms.gov:8443/mesh/imp1/NationalStudentClearinghouseService returned HTTP 200"
      ).and_call_original

      response = service.fetch_enrollment_data(
        first_name: "Lynnette",
        last_name: "Oyola",
        date_of_birth: Date.new(1988, 10, 24),
        as_of_date: Date.new(2024, 11, 30)
      )

      expect(response).to include("enrollmentDetails")
      expect(response["enrollmentDetails"]).to contain_exactly(
        include(
          "officialSchoolName" => "Trident University International",
          "currentEnrollmentStatus" => "CC",
          "nameOnSchoolRecord" => include(
            "firstName" => "Lynnette",
            "lastName" => "Oyola"
          ),
          "enrollmentData" => contain_exactly(
            include(
              "enrollmentStatus" => "Y",
              "termBeginDate" => "2024-05-31",
              "termEndDate" => "2024-11-19"
            )
          )
        )
      )

      expect(a_request(:post, "#{base_url}/#{education_enrollment_url}")
        .with(
          body: {
            nscRequest: {
              personGivenName: "Lynnette",
              personSurName: "Oyola",
              personBirthDate: "1988-10-24",
              asOfDate: "2024-11-30",
              termsAcceptedIndicator: true
            }
          }.to_json,
          headers: {
            "Authorization" => "Bearer hub-access-token",
            "Content-Type" => "application/json"
          }
        )).to have_been_requested
    end

    it "caches the Hub access token until it expires" do
      stub_request(:post, "#{base_url}/#{education_enrollment_url}")
        .to_return(status: 200, body: fdsh_response.to_json)

      2.times do
        service.fetch_enrollment_data(
          first_name: "Lynnette",
          last_name: "Oyola",
          date_of_birth: Date.new(1988, 10, 24),
          as_of_date: Date.new(2024, 11, 30)
        )
      end

      expect(a_request(:post, token_url)).to have_been_requested.once
    end

    it "raises an authentication error and clears the token after a 401" do
      stub_request(:post, "#{base_url}/#{education_enrollment_url}").to_return(status: 401, body: "unauthorized")

      expect do
        service.fetch_enrollment_data(
          first_name: "Lynnette",
          last_name: "Oyola",
          date_of_birth: Date.new(1988, 10, 24),
          as_of_date: Date.new(2024, 11, 30)
        )
      end.to raise_error(described_class::AuthenticationError)

      expect(service.send(:instance_variable_get, :@token)).to be_nil
    end

    it "does not request an access token when OAuth client credentials are missing" do
      [
        { client_id: nil, client_secret: "client-secret", missing: "HUB_CLIENT_KEY" },
        { client_id: "client-id", client_secret: nil, missing: "HUB_CLIENT_SECRET" }
      ].each do |credentials|
        service_without_credentials = described_class.new(
          client_id: credentials[:client_id],
          client_secret: credentials[:client_secret],
          client_cert: certificate,
          client_key: private_key,
          logger: logger
        )
        message = "Cannot request FDSH OAuth access token: missing #{credentials[:missing]}"

        expect(logger).to receive(:error).with(message)
        expect do
          service_without_credentials.send(:access_token)
        end.to raise_error(described_class::ApiError, message)
      end

      expect(a_request(:post, token_url)).not_to have_been_requested
    end
  end

  describe "certificate configuration" do
    it "raises a configuration error when the certificate and certificate path are empty" do
      ClimateControl.modify(HUB_CERT: "", HUB_CERT_PATH: "") do
        expect do
          described_class.new(logger: logger)
        end.to raise_error(described_class::ApiError, /HUB_CERT or HUB_CERT_PATH/)
      end
    end

    it "raises a configuration error when the certificate is invalid" do
      ClimateControl.modify(HUB_CERT: "invalid certificate", HUB_CERT_PATH: nil) do
        expect do
          described_class.new(logger: logger)
        end.to raise_error(described_class::ApiError, /Could not load HUB_CERT/)
      end
    end

    it "raises a configuration error when a configured certificate file is missing" do
      ClimateControl.modify(HUB_CERT: nil, HUB_CERT_PATH: "/tmp/does-not-exist/client.crt") do
        expect do
          described_class.new(logger: logger)
        end.to raise_error(described_class::ApiError, /Could not load HUB_CERT/)
      end
    end

    it "raises a configuration error when the private key and key path are empty" do
      ClimateControl.modify(
        HUB_CERT: certificate.to_pem,
        HUB_CERT_PATH: nil,
        HUB_CERT_KEY: "",
        HUB_CERT_KEY_PATH: ""
      ) do
        expect do
          described_class.new(logger: logger)
        end.to raise_error(described_class::ApiError, /HUB_CERT_KEY or HUB_CERT_KEY_PATH/)
      end
    end

    it "raises a configuration error when the private key is invalid" do
      ClimateControl.modify(
        HUB_CERT: certificate.to_pem,
        HUB_CERT_PATH: nil,
        HUB_CERT_KEY: "invalid private key",
        HUB_CERT_KEY_PATH: nil
      ) do
        expect do
          described_class.new(logger: logger)
        end.to raise_error(described_class::ApiError, /Could not load HUB_CERT_KEY/)
      end
    end

    it "raises a configuration error when a configured private key file is missing" do
      ClimateControl.modify(
        HUB_CERT: certificate.to_pem,
        HUB_CERT_PATH: nil,
        HUB_CERT_KEY: nil,
        HUB_CERT_KEY_PATH: "/tmp/does-not-exist/client.key"
      ) do
        expect do
          described_class.new(logger: logger)
        end.to raise_error(described_class::ApiError, /Could not load HUB_CERT_KEY/)
      end
    end

    it "raises a configuration error when the certificate and key do not match" do
      other_key = OpenSSL::PKey::RSA.new(2048)
      ClimateControl.modify(
        HUB_CERT: certificate.to_pem,
        HUB_CERT_PATH: nil,
        HUB_CERT_KEY: other_key.to_pem,
        HUB_CERT_KEY_PATH: nil
      ) do
        expect do
          described_class.new(logger: logger)
        end.to raise_error(described_class::ApiError, /HUB_CERT and HUB_CERT_KEY must contain a matching/)
      end
    end

    it "loads credentials from the Hub environment variables" do
      ClimateControl.modify(
        HUB_CLIENT_KEY: "hub-client-id",
        HUB_CLIENT_SECRET: "hub-client-secret",
        HUB_CERT: certificate.to_pem,
        HUB_CERT_KEY: private_key.to_pem
      ) do
        configured_service = described_class.new(logger: logger)

        expect(configured_service.instance_variable_get(:@client_id)).to eq("hub-client-id")
        expect(configured_service.instance_variable_get(:@client_secret)).to eq("hub-client-secret")
        expect(configured_service.instance_variable_get(:@client_cert).to_pem).to eq(certificate.to_pem)
        expect(configured_service.instance_variable_get(:@client_key).to_pem).to eq(private_key.to_pem)
      end
    end
  end

  describe "development localhost override" do
    it "ignores HUB_LOCALHOST_OVERRIDE outside development" do
      non_development_service = described_class.new(
        localhost_override: "true",
        client_cert: certificate,
        client_key: private_key,
        logger: logger
      )

      expect(non_development_service.send(:instance_variable_get, :@localhost_override)).to be false
    end

    it "uses the local tunnel IP while preserving the Hub hostname in development" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      development_service = described_class.new(
        localhost_override: "true",
        client_cert: certificate,
        client_key: private_key,
        logger: logger
      )
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).with("impl.hub.cms.gov", 8443).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:cert=)
      allow(http).to receive(:key=)
      allow(http).to receive(:min_version=)
      allow(http).to receive(:max_version=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      expect(http).to receive(:ipaddr=).with("127.0.0.1")

      development_service.send(:build_http, URI(base_url))
    end
  end

  describe "#build_http" do
    it "configures the client certificate and TLS 1.2" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).with("impl.hub.cms.gov", 8443).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:cert=)
      allow(http).to receive(:key=)
      allow(http).to receive(:min_version=)
      allow(http).to receive(:max_version=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      expect(http).to receive(:cert=).with(certificate)
      expect(http).to receive(:key=).with(an_instance_of(OpenSSL::PKey::RSA))
      expect(http).to receive(:use_ssl=).with(true)
      expect(http).to receive(:min_version=).with(described_class::TLS_VERSION)
      expect(http).to receive(:max_version=).with(described_class::TLS_VERSION)

      service.send(:build_http, URI(base_url))
    end
  end
end

# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "securerandom"
require "uri"

module Aggregators
  module Sdk
    # Client for the National Student Clearinghouse service exposed through FDSH.
    #
    # The Hub requires mutual TLS for both the OAuth token request and the NSC
    # request. In local development, HUB_LOCALHOST_OVERRIDE points the Hub
    # hostname at the local end of an SSH tunnel while preserving the hostname
    # used for TLS.
    class NscFdshService
      DEFAULT_BASE_URL = "https://impl.hub.cms.gov"
      DEFAULT_TOKEN_URL = "#{DEFAULT_BASE_URL}/auth/oauth/v2/token"
      DEFAULT_EDUCATION_ENROLLMENT_URL = "mesh/imp1/NationalStudentClearinghouseService"
      EDUCATION_ENROLLMENT_URL = DEFAULT_EDUCATION_ENROLLMENT_URL
      LOCALHOST_PORT = 8443

      MAX_TIMEOUT = 10
      TLS_VERSION = OpenSSL::SSL::TLS1_2_VERSION

      class ApiError < StandardError
        attr_reader :code

        def initialize(code:, message:)
          @code = code
          super(message)
        end
      end

      class AuthenticationError < ApiError; end

      def initialize(
        environment: nil,
        logger: nil,
        base_url: ENV.fetch("HUB_API_URL", DEFAULT_BASE_URL),
        client_id: ENV["HUB_CLIENT_ID"],
        client_secret: ENV["HUB_CLIENT_SECRET"],
        client_cert_path: ENV["HUB_CLIENT_CERT_PATH"],
        client_key_path: ENV["HUB_CLIENT_KEY_PATH"],
        client_cert: ENV["HUB_CLIENT_CERT"],
        client_key: ENV["HUB_CLIENT_KEY"],
        localhost_override: ENV["HUB_LOCALHOST_OVERRIDE"],
        token_url: DEFAULT_TOKEN_URL,
        education_enrollment_url: DEFAULT_EDUCATION_ENROLLMENT_URL
      )
        # Keep accepting environment for parity with NscService and callers
        # that select an NSC environment, even though FDSH selects its target
        # through Hub configuration instead.
        @environment = environment
        @base_url = base_url
        @token_url = token_url
        @client_id = client_id
        @client_secret = client_secret
        @client_cert = load_certificate(client_cert, client_cert_path)
        @client_key = load_key(client_key, client_key_path)
        @localhost_override = development? && parse_boolean(localhost_override)
        @education_enrollment_url = education_enrollment_url
        @token = nil
        @token_expires_at = nil
        @logger = logger || Rails.logger.tagged("NscFdshService")
      end

      # Returns the same response shape as NscService so the education flow
      # does not need to know whether NSC was reached directly or through FDSH.
      def fetch_enrollment_data(first_name:, last_name:, date_of_birth:, as_of_date:)
        payload = {
          "personGivenName" => first_name,
          "personSurName" => last_name,
          "personBirthDate" => date_of_birth.to_s,
          "asOfDate" => as_of_date.to_s,
          "termsAcceptedIndicator" => true
        }

        normalize_response(get_education_enrollment_v1(payload))
      end

      def get_education_enrollment_v1(payload)
        post(@education_enrollment_url, { "nscRequest" => payload })
      end

      private

      def post(path, body)
        uri = build_uri(@base_url, path)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{access_token}"
        request["messageID"] = SecureRandom.uuid
        request.body = body.to_json

        execute(uri, request)
      end

      def fetch_token
        uri = URI(@token_url)
        @logger.info("Requesting FDSH OAuth token from #{@token_url}")
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(
          grant_type: "client_credentials",
          client_id: @client_id,
          client_secret: @client_secret
        )

        execute(uri, request)
      end

      def access_token
        return @token if @token.present? && (@token_expires_at.nil? || Time.current < @token_expires_at)

        response = fetch_token
        @token = response.fetch("access_token")
        expires_in = response["expires_in"].to_i
        @token_expires_at = expires_in.positive? ? Time.current + expires_in.seconds - 30.seconds : nil
        @token
      rescue KeyError
        raise AuthenticationError.new(code: "OAUTH_ERROR", message: "OAuth token not found in response")
      end

      def execute(uri, request)
        http = build_http(uri)
        response = http.start { http.request(request) }
        handle_response(response)
      rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
        raise ApiError.new(code: "CONNECTION_ERROR", message: "FDSH connection failed: #{e.message}")
      end

      def build_http(uri)
        port = @localhost_override ? LOCALHOST_PORT : uri.port
        http = Net::HTTP.new(uri.hostname, port)
        http.ipaddr = "127.0.0.1" if @localhost_override
        http.use_ssl = uri.scheme == "https"
        http.cert = @client_cert if @client_cert
        http.key = @client_key if @client_key
        http.min_version = TLS_VERSION
        http.max_version = TLS_VERSION
        http.open_timeout = MAX_TIMEOUT
        http.read_timeout = MAX_TIMEOUT
        http
      end

      def handle_response(response)
        case response.code.to_i
        when 200..299
          parse_response(response.body)
        when 401
          @token = nil
          @token_expires_at = nil
          raise AuthenticationError.new(code: "UNAUTHORIZED", message: "Unauthorized: #{response.body}")
        else
          raise ApiError.new(
            code: response.code.to_i,
            message: "FDSH request failed with status #{response.code}: #{response.body}"
          )
        end
      end

      def parse_response(body)
        JSON.parse(body)
      rescue JSON::ParserError => e
        raise ApiError.new(code: "INVALID_RESPONSE", message: "FDSH returned invalid JSON: #{e.message}")
      end

      def normalize_response(response)
        return response if response.key?("enrollmentDetails")

        fdsh_response = response.fetch("nscResponse", response)
        student_info = fdsh_response["studentInfoProvided"] || {}
        name_on_school_record = {
          "firstName" => student_info["personGivenName"],
          "middleName" => student_info["personMiddleName"],
          "lastName" => student_info["personSurName"]
        }

        normalized = fdsh_response.slice("transactionDetails")
        normalized["studentInfoProvided"] = student_info if response.key?("studentInfoProvided") || fdsh_response.key?("studentInfoProvided")
        normalized["enrollmentDetails"] = Array(fdsh_response["enrollmentDetails"]).map do |detail|
          {
            "officialSchoolName" => detail["officialSchoolName"],
            "schoolCode" => detail["schoolCode"],
            "currentEnrollmentStatus" => detail["currentEnrollmentStatusCode"],
            "nameOnSchoolRecord" => name_on_school_record,
            "enrollmentData" => Array(detail["enrollmentData"]).map do |term|
              {
                "enrollmentStatus" => term["enrollmentStatusCode"],
                "termBeginDate" => term["termBeginDate"],
                "termEndDate" => term["termEndDate"]
              }
            end
          }
        end
        normalized
      end

      def build_uri(base_url, path)
        URI.join("#{base_url.chomp("/")}/", path.to_s.sub(%r{\A/}, ""))
      end

      def parse_boolean(value)
        case value.to_s.downcase
        when "true"
          true
        when "", "false"
          false
        else
          raise ApiError.new(code: "CONFIGURATION_ERROR", message: "HUB_LOCALHOST_OVERRIDE must be true or false")
        end
      end

      def development?
        Rails.env.development?
      end

      def load_certificate(value, path)
        return OpenSSL::X509::Certificate.new(value) if value.present?
        return unless path.present?

        OpenSSL::X509::Certificate.new(File.read(File.expand_path(path)))
      rescue Errno::ENOENT, OpenSSL::X509::CertificateError => e
        raise ApiError.new(code: "CONFIGURATION_ERROR", message: "Failed to load FDSH client certificate: #{e.message}")
      end

      def load_key(value, path)
        return OpenSSL::PKey.read(value) if value.present?
        return unless path.present?

        OpenSSL::PKey.read(File.read(File.expand_path(path)))
      rescue Errno::ENOENT, OpenSSL::PKey::PKeyError, OpenSSL::OpenSSLError => e
        raise ApiError.new(code: "CONFIGURATION_ERROR", message: "Failed to load FDSH client key: #{e.message}")
      end
    end
  end
end

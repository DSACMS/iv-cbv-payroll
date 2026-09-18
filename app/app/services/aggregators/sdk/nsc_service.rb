# frozen_string_literal: true

require "faraday"
require "openssl"

module Aggregators
  module Sdk
    class NscService
      ENVIRONMENTS = {
        sandbox: {
          base_url: ENV["NSC_API_URL_SANDBOX"],
          token_url: ENV["NSC_TOKEN_URL_SANDBOX"],
          client_id: ENV["NSC_CLIENT_ID_SANDBOX"],
          client_secret: ENV["NSC_CLIENT_SECRET_SANDBOX"],
          account_id: ENV["NSC_ACCOUNT_ID_SANDBOX"],
          client_cert: ENV["NSC_CLIENT_CERT_SANDBOX"] || ENV["NSC_CLIENT_CERT"],
          client_cert_path: ENV["NSC_CLIENT_CERT_PATH_SANDBOX"] || ENV["NSC_CLIENT_CERT_PATH"],
          client_key: ENV["NSC_CLIENT_KEY_SANDBOX"] || ENV["NSC_CLIENT_KEY"],
          client_key_path: ENV["NSC_CLIENT_KEY_PATH_SANDBOX"] || ENV["NSC_CLIENT_KEY_PATH"],
          client_key_password: ENV["NSC_CLIENT_KEY_PASSWORD_SANDBOX"] || ENV["NSC_CLIENT_KEY_PASSWORD"],
          scope: "vs.api.insights"
        },
        production: {
          base_url: ENV["NSC_API_URL"],
          token_url: ENV["NSC_TOKEN_URL"],
          client_id: ENV["NSC_CLIENT_ID"],
          client_secret: ENV["NSC_CLIENT_SECRET"],
          account_id: ENV["NSC_ACCOUNT_ID"],
          client_cert: ENV["NSC_CLIENT_CERT"],
          client_cert_path: ENV["NSC_CLIENT_CERT_PATH"],
          client_key: ENV["NSC_CLIENT_KEY"],
          client_key_path: ENV["NSC_CLIENT_KEY_PATH"],
          client_key_password: ENV["NSC_CLIENT_KEY_PASSWORD"],
          scope: "vs.api.insights"
        }
      }.freeze

      # See: https://docs.studentclearinghouse.org/vs/insights-json/verification-services-request#service-url-jwt-encryption-path
      ENROLLMENT_ENDPOINT = "/insights/v3/a2/submit-request"
      MIN_DISPLAY_TIME = 2.seconds
      MAX_TIMEOUT = 10.seconds

      class ApiError < StandardError
        attr_reader :code, :message, :status, :failure_origin, :error_type, :endpoint, :details

        def initialize(code:, message:, status: nil, failure_origin: :application, error_type: :api_error, endpoint: nil, details: {})
          @code = code
          @message = message
          @status = status
          @failure_origin = failure_origin.to_sym
          @error_type = error_type.to_sym
          @endpoint = endpoint
          @details = details
          super("NSC API Error - Code: #{code}, Message: #{message}, Origin: #{failure_origin}, Type: #{error_type}")
        end

        def hub_side?
          @failure_origin == :hub
        end

        def application_side?
          @failure_origin == :application
        end

        def tls_cert_error?
          @failure_origin == :tls || @error_type == :tls_cert_error
        end

        def timeout?
          @error_type == :timeout
        end

        def connection_error?
          @error_type == :connection_error
        end
      end

      class ConnectionError < ApiError
        def initialize(code: "CONNECTION_FAILED", message: "Failed to connect to NSC/Hub", endpoint: nil, details: {}, status: nil)
          super(code: code, message: message, status: status, failure_origin: :hub, error_type: :connection_error, endpoint: endpoint, details: details)
        end
      end

      class TimeoutError < ApiError
        def initialize(code: "TIMEOUT", message: "NSC/Hub request timed out", endpoint: nil, details: {}, status: nil)
          super(code: code, message: message, status: status, failure_origin: :hub, error_type: :timeout, endpoint: endpoint, details: details)
        end
      end

      class TlsCertError < ApiError
        def initialize(code: "TLS_CERT_ERROR", message: "TLS/Certificate error during NSC/Hub communication", endpoint: nil, details: {}, status: nil)
          super(code: code, message: message, status: status, failure_origin: :tls, error_type: :tls_cert_error, endpoint: endpoint, details: details)
        end
      end

      class ServerError < ApiError
        def initialize(code: "SERVER_ERROR", message: "NSC/Hub internal server error", endpoint: nil, details: {}, status: nil)
          super(code: code, message: message, status: status, failure_origin: :hub, error_type: :server_error, endpoint: endpoint, details: details)
        end
      end

      class RateLimitError < ApiError
        def initialize(code: "RATE_LIMITED", message: "NSC/Hub rate limit exceeded", endpoint: nil, details: {}, status: 429)
          super(code: code, message: message, status: status, failure_origin: :hub, error_type: :rate_limit, endpoint: endpoint, details: details)
        end
      end

      class AuthError < ApiError
        def initialize(code: "UNAUTHORIZED", message: "NSC/Hub authentication failed", endpoint: nil, details: {}, status: nil)
          super(code: code, message: message, status: status, failure_origin: :application, error_type: :auth_error, endpoint: endpoint, details: details)
        end
      end

      class ClientError < ApiError
        def initialize(code: "CLIENT_ERROR", message: "Invalid request to NSC/Hub", endpoint: nil, details: {}, status: nil)
          super(code: code, message: message, status: status, failure_origin: :application, error_type: :client_error, endpoint: endpoint, details: details)
        end
      end

      class ConfigurationError < ApiError
        def initialize(code: "CONFIGURATION_ERROR", message: "NSC/Hub configuration error", endpoint: nil, details: {})
          super(code: code, message: message, status: nil, failure_origin: :application, error_type: :configuration_error, endpoint: endpoint, details: details)
        end
      end

      def initialize(environment: :sandbox, logger: nil)
        @environment = ENVIRONMENTS.fetch(environment.to_sym) do |env|
          raise KeyError, "NscService unknown environment: #{env}"
        end
        @base_url = @environment[:base_url]
        @logger = if logger
                    logger
                  elsif ENV.fetch("STRUCTURED_LOGGING_ENABLED", "false") == "true"
                    SemanticLogger["NscService"]
                  else
                    Rails.logger.tagged("NscService")
                  end

        @logger.info("Initialized in #{environment} environment (with base URL: #{@base_url})")
      end

      # Fetch enrollment data from NSC API
      #
      # @param first_name [String] First name of the individual
      # @param last_name [String] Last name of the individual
      # @param date_of_birth [Date] Date of birth of the individual
      # @return [Hash] Parsed JSON response from NSC API
      def fetch_enrollment_data(first_name:, last_name:, date_of_birth:, as_of_date:)
        request_body = {
          firstName: first_name,
          lastName: last_name,
          dateOfBirth: date_of_birth,
          asOfDate: as_of_date,
          accountId: environment_name == :production ? ENV["NSC_ACCOUNT_ID"] : ENV["NSC_ACCOUNT_ID_SANDBOX"],
          terms: "Y",
          endClient: "CMS"
        }

        full_url = "#{@base_url}#{ENROLLMENT_ENDPOINT}"
        @logger.info("Fetch enrollment data: POST to #{full_url}")

        retried = false

        begin
          response = execute_request("submit_request", full_url) do
            http_client.post(full_url) do |req|
              req.body = request_body
            end
          end

          @logger.info("Response Status: #{response.status}")
          handle_response(response, endpoint: "submit_request")
        rescue AuthError => e
          @logger.warn("Got auth error #{e.class}: #{e.message}")
          raise if Rails.env.development?

          # Try one more time if the issue was expired or invalid token
          raise unless e.code == "UNAUTHORIZED" && !retried
          retried = true
          # Try to fetch again
          retry
        rescue ApiError => e
          @logger.warn("Got error #{e.class}: #{e.message}")
          raise
        end
      end

      def http_client
        @http_client ||= Faraday.new do |conn|
          conn.request :json
          conn.response :logger, @logger, bodies: true, headers: true
          conn.response :json
          conn.options.timeout = MAX_TIMEOUT.to_i
          conn.options.open_timeout = MAX_TIMEOUT.to_i
          conn.headers["Authorization"] = "Bearer #{access_token}"
          conn.headers["Content-Type"] = "application/json"
          configure_ssl(conn)
        end
      end

      def access_token
        @access_token ||= fetch_oauth_token
      end

      def fetch_oauth_token
        token_url = @environment[:token_url]

        unless token_url.present?
          err = ConfigurationError.new(
            code: "MISSING_TOKEN_URL",
            message: "Token URL is not configured",
            endpoint: "oauth_token"
          )
          report_failure(err, endpoint: "oauth_token", failure_origin: :application, error_type: :configuration_error)
          raise err
        end

        @logger.info("Fetching OAuth token from #{token_url}")

        token_conn = Faraday.new do |conn|
          conn.request :url_encoded
          conn.response :logger, @logger, bodies: true, headers: true
          conn.response :json
          conn.options.timeout = MAX_TIMEOUT.to_i
          conn.options.open_timeout = MAX_TIMEOUT.to_i
          configure_ssl(conn)
        end

        response = execute_request("oauth_token", token_url) do
          token_conn.post(token_url) do |req|
            req.body = {
              grant_type: "client_credentials",
              scope: @environment[:scope],
              client_id: @environment[:client_id],
              client_secret: @environment[:client_secret]
            }
          end
        end

        unless response.success?
          status = response.status
          failure_origin = status >= 500 ? :hub : :application
          error_type = if status == 401 || status == 403
                         :auth_error
                       elsif status >= 500
                         :server_error
                       else
                         :client_error
                       end

          err_class = status >= 500 ? ServerError : (status == 401 || status == 403 ? AuthError : ClientError)
          err = err_class.new(
            code: response.status.to_s,
            message: "Failed to fetch OAuth token: #{response.status} - #{response.body}",
            status: response.status,
            endpoint: "oauth_token",
            details: { response_body: response.body }
          )
          report_failure(err, endpoint: "oauth_token", failure_origin: failure_origin, error_type: error_type, status: response.status)
          raise err
        end

        parsed_body = if response.body.is_a?(Hash)
                        response.body
                      elsif response.body.is_a?(String) && response.body.present?
                        begin
                          JSON.parse(response.body)
                        rescue JSON::ParserError
                          {}
                        end
                      else
                        {}
                      end

        token = parsed_body["access_token"]
        unless token.present?
          err = AuthError.new(
            code: "OAUTH_ERROR",
            message: "OAuth token not found in response",
            endpoint: "oauth_token",
            details: { response_body: response.body }
          )
          report_failure(err, endpoint: "oauth_token", failure_origin: :hub, error_type: :auth_error)
          raise err
        end

        @logger.info("Successfully fetched OAuth token (expires in #{response.body['expires_in']} seconds)")
        @access_token = token
      end

      def environment_name
        ENVIRONMENTS.key(@environment) || :unknown
      end

      def handle_response(response, endpoint: "submit_request")
        parsed_body = if response.body.is_a?(Hash)
                        response.body
                      elsif response.body.is_a?(String) && response.body.present?
                        begin
                          JSON.parse(response.body)
                        rescue JSON::ParserError
                          response.body
                        end
                      else
                        response.body
                      end

        case response.status
        when 200..299
          @logger.info("Successfully fetched enrollment data from NSC API. Response Body: #{response.body}")
          parsed_body
        when 404
          error_body = parsed_body.is_a?(Hash) ? parsed_body : {}
          code = error_body["code"] || "STUDENT_NOT_FOUND"
          message = error_body["message"] || "Student not found"
          @logger.error("Student not found: #{error_body}")
          err = ClientError.new(
            code: code,
            message: message,
            status: 404,
            endpoint: endpoint,
            details: { response_body: response.body }
          )
          report_failure(err, endpoint: endpoint, failure_origin: :application, error_type: :client_error, status: 404)
          raise err
        when 401
          @logger.error("Unauthorized access - invalid or expired token.")
          err = AuthError.new(
            code: "UNAUTHORIZED",
            message: "OAuth token expired or invalid",
            status: 401,
            endpoint: endpoint,
            details: { response_body: response.body }
          )
          report_failure(err, endpoint: endpoint, failure_origin: :application, error_type: :auth_error, status: 401)
          raise err
        when 403
          @logger.error("Forbidden access to NSC API: #{response.body}")
          err = AuthError.new(
            code: "FORBIDDEN",
            message: "Forbidden access to NSC API",
            status: 403,
            endpoint: endpoint,
            details: { response_body: response.body }
          )
          report_failure(err, endpoint: endpoint, failure_origin: :application, error_type: :auth_error, status: 403)
          raise err
        when 400, 422
          error_body = parsed_body.is_a?(Hash) ? parsed_body : {}
          code = error_body["code"] || "BAD_REQUEST"
          message = error_body["message"] || "Bad Request to NSC API"
          @logger.error("Client error (#{response.status}): #{response.body}")
          err = ClientError.new(
            code: code,
            message: message,
            status: response.status,
            endpoint: endpoint,
            details: { response_body: response.body }
          )
          report_failure(err, endpoint: endpoint, failure_origin: :application, error_type: :client_error, status: response.status)
          raise err
        when 429
          @logger.error("Rate limit exceeded from NSC API: #{response.body}")
          err = RateLimitError.new(
            code: "RATE_LIMITED",
            message: "Rate limit exceeded from NSC API",
            status: 429,
            endpoint: endpoint,
            details: { response_body: response.body }
          )
          report_failure(err, endpoint: endpoint, failure_origin: :hub, error_type: :rate_limit, status: 429)
          raise err
        when 500..599
          @logger.error("NSC API server error (#{response.status}): #{response.body}")
          err = ServerError.new(
            code: "SERVER_ERROR_#{response.status}",
            message: "NSC API server error: #{response.status} - #{response.body}",
            status: response.status,
            endpoint: endpoint,
            details: { response_body: response.body }
          )
          report_failure(err, endpoint: endpoint, failure_origin: :hub, error_type: :server_error, status: response.status)
          raise err
        else
          @logger.error("Unexpected API response: #{response.status} - #{response.body}")
          err = ApiError.new(
            code: "UNEXPECTED_RESPONSE_#{response.status}",
            message: "Unexpected error occurred from NSC API: #{response.status} - #{response.body}",
            status: response.status,
            failure_origin: response.status >= 500 ? :hub : :application,
            error_type: response.status >= 500 ? :server_error : :client_error,
            endpoint: endpoint,
            details: { response_body: response.body }
          )
          report_failure(err, endpoint: endpoint, failure_origin: err.failure_origin, error_type: err.error_type, status: response.status)
          raise err
        end
      end

      private

      def execute_request(endpoint, url)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          response = yield
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          report_success(endpoint: endpoint, duration_ms: duration_ms) if response.is_a?(Faraday::Response) && response.success?
          response
        rescue Faraday::TimeoutError, Net::ReadTimeout, Net::OpenTimeout, Timeout::Error, Errno::ETIMEDOUT => e
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          err = TimeoutError.new(
            code: "TIMEOUT",
            message: "Timeout communicating with NSC/Hub at #{url}: #{e.message}",
            endpoint: endpoint,
            details: { url: url, original_error: e.class.name }
          )
          report_failure(err, endpoint: endpoint, failure_origin: :hub, error_type: :timeout, duration_ms: duration_ms)
          raise err
        rescue Faraday::SSLError, OpenSSL::SSL::SSLError, OpenSSL::X509::CertificateError => e
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          err = TlsCertError.new(
            code: "TLS_CERT_ERROR",
            message: "TLS/Certificate error communicating with NSC/Hub at #{url}: #{e.message}",
            endpoint: endpoint,
            details: { url: url, original_error: e.class.name }
          )
          report_failure(err, endpoint: endpoint, failure_origin: :tls, error_type: :tls_cert_error, duration_ms: duration_ms)
          raise err
        rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          if e.message.to_s.match?(/execution expired|timed? ?out/i)
            err = TimeoutError.new(
              code: "TIMEOUT",
              message: "Timeout communicating with NSC/Hub at #{url}: #{e.message}",
              endpoint: endpoint,
              details: { url: url, original_error: e.class.name }
            )
            report_failure(err, endpoint: endpoint, failure_origin: :hub, error_type: :timeout, duration_ms: duration_ms)
          else
            err = ConnectionError.new(
              code: "CONNECTION_FAILED",
              message: "Connection failed to NSC/Hub at #{url}: #{e.message}",
              endpoint: endpoint,
              details: { url: url, original_error: e.class.name }
            )
            report_failure(err, endpoint: endpoint, failure_origin: :hub, error_type: :connection_error, duration_ms: duration_ms)
          end
          raise err
        rescue ApiError => e
          raise
        rescue => e
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          err = ApiError.new(
            code: "UNEXPECTED_ERROR",
            message: "Unexpected error during NSC/Hub request to #{url}: #{e.message}",
            failure_origin: :application,
            error_type: :unknown_error,
            endpoint: endpoint,
            details: { url: url, original_error: e.class.name }
          )
          report_failure(err, endpoint: endpoint, failure_origin: :application, error_type: :unknown_error, duration_ms: duration_ms)
          raise err
        end
      end

      def report_failure(error, endpoint:, failure_origin:, error_type:, status: nil, duration_ms: nil)
        origin_label = failure_origin == :hub ? "Hub-side" : (failure_origin == :tls ? "TLS/Cert" : "Application-side")
        @logger.error("[NSC/Hub Failure] origin=#{failure_origin} type=#{error_type} endpoint=#{endpoint} status=#{status || 'N/A'} env=#{environment_name} classification=\"#{origin_label}\" message=#{error.message}")

        if defined?(NewRelic::Agent)
          NewRelic::Agent.record_metric("Custom/NSC/Calls", 1)
          NewRelic::Agent.record_metric("Custom/NSC/Failure", 1)
          NewRelic::Agent.record_metric("Custom/NSC/Failure/#{failure_origin}", 1)
          NewRelic::Agent.record_metric("Custom/NSC/Failure/#{error_type}", 1)
          NewRelic::Agent.record_custom_event("NscApiFailure", {
            failure_origin: failure_origin.to_s,
            error_type: error_type.to_s,
            endpoint: endpoint.to_s,
            status_code: status,
            environment: environment_name.to_s,
            error_message: error.message.to_s.truncate(255),
            duration_ms: duration_ms
          })
          NewRelic::Agent.record_custom_event("NscApiCall", {
            status: "failure",
            failure_origin: failure_origin.to_s,
            error_type: error_type.to_s,
            endpoint: endpoint.to_s,
            status_code: status,
            environment: environment_name.to_s,
            duration_ms: duration_ms
          })
          NewRelic::Agent.notice_error(error, custom_params: {
            endpoint: endpoint,
            failure_origin: failure_origin,
            error_type: error_type,
            status_code: status,
            environment: environment_name
          })
        end
      end

      def report_success(endpoint:, duration_ms:)
        if defined?(NewRelic::Agent)
          NewRelic::Agent.record_metric("Custom/NSC/Calls", 1)
          NewRelic::Agent.record_metric("Custom/NSC/Success", 1)
          NewRelic::Agent.record_custom_event("NscApiCall", {
            status: "success",
            endpoint: endpoint.to_s,
            environment: environment_name.to_s,
            duration_ms: duration_ms
          })
        end
      end

      def configure_ssl(conn)
        cert = load_client_cert
        key = load_client_key

        if cert.present? && key.present?
          conn.ssl.client_cert = cert
          conn.ssl.client_key = key
        end
      rescue OpenSSL::X509::CertificateError, OpenSSL::PKey::PKeyError => e
        @logger.error("Failed to load NSC client certificate or key: #{e.message}")
        raise TlsCertError.new(
          code: "INVALID_CERT_CONFIG",
          message: "Failed to configure NSC client certificate/key: #{e.message}",
          details: { error: e.message }
        )
      end

      def load_client_cert
        cert_data = @environment[:client_cert]
        cert_path = @environment[:client_cert_path]

        if cert_data.present?
          cert_data.is_a?(OpenSSL::X509::Certificate) ? cert_data : OpenSSL::X509::Certificate.new(cert_data)
        elsif cert_path.present? && File.exist?(cert_path)
          OpenSSL::X509::Certificate.new(File.read(cert_path))
        end
      end

      def load_client_key
        key_data = @environment[:client_key]
        key_path = @environment[:client_key_path]
        password = @environment[:client_key_password]

        if key_data.present?
          key_data.is_a?(OpenSSL::PKey::PKey) ? key_data : OpenSSL::PKey.read(key_data, password)
        elsif key_path.present? && File.exist?(key_path)
          OpenSSL::PKey.read(File.read(key_path), password)
        end
      end
    end
  end
end

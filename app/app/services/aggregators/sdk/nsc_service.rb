# frozen_string_literal: true

require "faraday"

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
          scope: "vs.api.insights"
        },
        production: {
          base_url: ENV["NSC_API_URL"],
          token_url: ENV["NSC_TOKEN_URL"],
          client_id: ENV["NSC_CLIENT_ID"],
          client_secret: ENV["NSC_CLIENT_SECRET"],
          account_id: ENV["NSC_ACCOUNT_ID"],
          scope: "vs.api.insights"
        }
      }.freeze

      # See: https://docs.studentclearinghouse.org/vs/insights-json/verification-services-request#service-url-jwt-encryption-path
      ENROLLMENT_ENDPOINT = "/insights/v3/a2/submit-request"
      MIN_DISPLAY_TIME = 2.seconds
      MAX_TIMEOUT = 10.seconds

      class ApiError < StandardError
        attr_reader :code, :message

        def initialize(code:, message:)
          @code = code
          @message = message
          super("NSC API Error - Code: #{code}, Message: #{message}")
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
          response = http_client.post(full_url) do |req|
            req.body = request_body
          end

          @logger.info("Response Status: #{response.status}")

          shift_enrollment_dates_for_demo(handle_response(response))
        rescue ApiError => e
          @logger.warn("Got error #{e.class}: #{e.message}")
          raise if Rails.env.development?

          # Try one more time if the issue was expired or invalid token
          raise unless e.code == "UNAUTHORIZED" && !retried
          retried = true
          # Try to fetch again
          retry
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
        end
      end

      def access_token
        fetch_oauth_token
      end

      def fetch_oauth_token
        token_url = @environment[:token_url]

        unless token_url.present?
          @logger.warn "Token URL is not configured."
          return nil
        end

        @logger.info("Fetching OAuth token from #{token_url}")

        token_conn = Faraday.new do |conn|
          conn.request :url_encoded
          conn.response :logger, @logger, bodies: true, headers: true
          conn.response :json
          conn.options.timeout = MAX_TIMEOUT.to_i
        end

        response = token_conn.post(token_url) do |req|
          req.body = {
            grant_type: "client_credentials",
            scope: @environment[:scope],
            client_id: @environment[:client_id],
            client_secret: @environment[:client_secret]
          }
        end

        unless response.success?
          @logger.error("Failed to fetch OAuth token: #{response.status} - #{response.body}")
          raise ApiError.new(
            code: response.status,
            message: "Failed to fetch OAuth token"
          )
        end

        token = response.body["access_token"]
        raise ApiError.new(
          code: "OAUTH_ERROR",
          message: "OAuth token not found in response"
        ) unless token.present?

        @logger.info("Successfully fetched OAuth token (expires in #{response.body['expires_in']} seconds)")

        token
      end

      def environment_name
        ENVIRONMENTS.key(@environment) || :unknown
      end

      # In demo and development environments, shift enrollment term dates for
      # currently-enrolled (CC) students so they overlap with a recent reporting
      # window. This is necessary because NSC sandbox test data has dates from
      # 1+ years ago, which would never overlap with a real reporting window.
      #
      # The shift targets the 15th of the previous month so the terms overlap
      # with both 1-month (application) and 6-month (renewal) reporting windows.
      #
      # Only date fields are modified; the number, type, and structure of
      # enrollment terms are preserved exactly.
      def shift_enrollment_dates_for_demo(response_body)
        return response_body unless demo_mode?

        enrollment_details = response_body["enrollmentDetails"]
        return response_body if enrollment_details.blank?

        cc_enrollments = enrollment_details.select { |ed| ed["currentEnrollmentStatus"] == "CC" }
        return response_body if cc_enrollments.empty?

        # Find the latest termEndDate across all CC enrollment terms
        max_term_end = cc_enrollments
          .flat_map { |ed| ed["enrollmentData"] || [] }
          .filter_map { |term| Date.parse(term["termEndDate"]) rescue nil }
          .max

        return response_body if max_term_end.nil?

        # Target: 15th of the previous month
        target_date = Date.today.beginning_of_month - 15.days
        offset_days = (target_date - max_term_end).to_i

        return response_body if offset_days == 0

        @logger.info("Demo mode: shifting CC enrollment dates by #{offset_days} days")

        cc_enrollments.each do |enrollment_detail|
          (enrollment_detail["enrollmentData"] || []).each do |term|
            %w[termBeginDate termEndDate schoolCertifiedOnDate].each do |date_field|
              next unless term[date_field].present?

              original_date = Date.parse(term[date_field])
              term[date_field] = (original_date + offset_days.days).iso8601
            end
          end
        end

        response_body
      end

      def demo_mode?
        Rails.application.config.demo_mode || Rails.env.development?
      end

      def handle_response(response)
        case response.status
        when 200
          @logger.info("Successfully fetched enrollment data from NSC API. Response Body: #{response.body}")
          response.body
        when 404
          error_body = response.body || {}
          @logger.error("Student not found: #{error_body}")
          raise ApiError.new(
            code: error_body["code"] || "STUDENT_NOT_FOUND",
            message: error_body["message"] || "Student not found"
          )
        when 401
          @logger.error("Unauthorized access - invalid or expired token.")
          raise ApiError.new(
            code: "UNAUTHORIZED",
            message: "OAuth token expired or invalid"
          )
        else
          @logger.error("Unexpected API response: #{response.status} - #{response.body}")
          raise ApiError.new(
            code: "UNEXPECTED_ERROR",
            message: "Unexpected error occurred from NSC API: #{response.status} - #{response.body}"
          )
        end
      end
    end
  end
end

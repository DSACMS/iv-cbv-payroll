# frozen_string_literal: true

require "faraday"

module Aggregators::Sdk
  class NscService
    ENVIRONMENTS = {
      sandbox: {
        base_url: ENV["NSC_API_URL_SANDBOX"],
        token_url: ENV["NSC_TOKEN_URL_SANDBOX"],
        client_id: ENV["NSC_CLIENT_ID_SANDBOX"],
        client_secret: ENV["NSC_CLIENT_SECRET_SANDBOX"],
        scope: "vs.api.insights"
      },
      production: {
        base_url: ENV["NSC_API_URL"],
        token_url: ENV["NSC_TOKEN_URL"],
        client_id: ENV["NSC_CLIENT_ID"],
        client_secret: ENV["NSC_CLIENT_SECRET"],
        scope: "vs.api.insights"
      }
    }.freeze

    ENROLLMENT_ENDPOINT = "/insights/v3/a2/submit-request"
    TOKEN_CACHE_KEY_PREFIX = "nsc_service_token_"
    TOKEN_EXPIRY_BUFFER = 5.minutes
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

    def initialize(environment: :sandbox)
      @environment = ENVIRONMENTS.fetch(environment.to_sym) do |env|
        raise KeyError, "NscService unknown environment: #{env}"
      end
      @base_url = @environment[:base_url]
      Rails.logger.info("[NscService] Initialized in #{environment} environment (with base URL: #{@base_url})")
    end

    # Main entry pont to submit an enrollment request to NSC
    def call(activity_flow, &block)
      start_time = Time.current

      yield if block_given?

      identity = activity_flow.identity
      response = fetch_enrollment_data(
        first_name: identity.first_name,
        last_name: identity.last_name,
        date_of_birth: identity.date_of_birth
      )

      create_education_activity(activity_flow, response)
    end

    # Fetch enrollment data from NSC API
    #
    # @param first_name [String] First name of the individual
    # @param last_name [String] Last name of the individual
    # @param date_of_birth [Date] Date of birth of the individual
    # @return [Hash] Parsed JSON response from NSC API
    #
    # TODO:
    #   - Make the terms dynamic based on user consent
    def fetch_enrollment_data(first_name:, last_name:, date_of_birth:)
      request_body = {
        firstName: first_name,
        lastName: last_name,
        dateOfBirth: date_of_birth,
        accountId: 10053523,
        terms: "y",
        endClient: "CMS"
      }

      full_url = "#{@base_url}#{ENROLLMENT_ENDPOINT}"
      Rails.logger.info("[NSCService] Fetch enrollment data:: POST to #{full_url} with body: #{request_body.to_json}")

      response = http_client.post(full_url) do |req|
        req.body = request_body
      end

      Rails.logger.info("[NscService] Response Status: #{response.status}, Body: #{response.body}")

      handle_response(response)
    end

    def http_client
      @http_client ||= Faraday.new do |conn|
        conn.request :json
        conn.response :logger, Rails.logger, bodies: true, headers: true, prefix: "[NscService][HTTP]"
        conn.response :json
        conn.options.timeout = MAX_TIMEOUT.to_i
        conn.options.open_timeout = MAX_TIMEOUT.to_i
        conn.headers["Authorization"] = "Bearer #{access_token}"
        conn.headers["Content-Type"] = "application/json"
      end
    end

    def access_token
      cache_key = "#{TOKEN_CACHE_KEY_PREFIX}_#{environment_name}"
      token_ttl = 1.hour - TOKEN_EXPIRY_BUFFER

      Rails.cache.fetch(cache_key, expires_in: token_ttl) do
        fetch_oauth_token
      end
    end

    def fetch_oauth_token
      token_url = @environment[:token_url]

      unless token_url.present?
        Rails.logger.warn "[NscService] Token URL is not configured."
        return nil
      end

      Rails.logger.info("[NscService] Fetching OAuth token from #{token_url}")

      token_conn = Faraday.new do |conn|
        conn.request :url_encoded
        conn.response :logger, Rails.logger, bodies: true, headers: true, prefix: "[NscService][HTTP]"
        conn.response :json
        conn.options.timeout = 10
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
        Rails.logger.error("[NscService] Failed to fetch OAuth token: #{response.status} - #{response.body}")
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

      Rails.logger.info("[NscService] Successfully fetched OAuth token (expires in #{response.body['expires_in']} seconds)")

      token
    end

    def environment_name
      ENVIRONMENTS.key(@environment)&.to_s || "unknown"
    end

    def handle_response(response)
      case response.status
      when 200
        Rails.logger.info("[NscService] Successfully fetched enrollment data from NSC API. Response Body: #{response.body}")
        response.body
      when 404
        error_body = response.body || {}
        Rails.logger.error("[NscService] Student not found: #{error_body}")
        raise ApiError.new(
          code: error_body["code"] || "STUDENT_NOT_FOUND",
          message: error_body["message"] || "Student not found"
        )
      when 401
        Rails.logger.error("[NscService] Unauthorized access - invalid or expired token. Clearing cached token.")
        # Clear cached token and retry once
        Rails.cache.delete("#{TOKEN_CACHE_KEY_PREFIX}_#{environment_name}")
        raise ApiError.new(
          code: "UNAUTHORIZED",
          message: "OAuth token expired or invalid"
        )
      else
        Rails.logger.error("[NscService] Unexpected API response: #{response.status} - #{response.body}")
        raise ApiError.new(
          code: "UNEXPECTED_ERROR",
          message: "Unexpected error occurred from NSC API: #{response.status} - #{response.body}"
        )
      end
    end

    # NOTE:
    # - Only handles the first enrollment school and the first enrollment detail (both are arrays in the response)
    # - Enrollment status is simply Y/N (until more use cases are known)
    def create_education_activity(activity_flow, response_data)
      currently_enrolled_schools = Array(response_data["enrollmentDetails"])
          .select { |enrollment| map_enrollment_status(enrollment["currentEnrollmentStatus"]) == :enrolled }
          .map { |enrollment| enrollment["officialSchoolName"] }

      Rails.logger.info("[NscService] create_education_activity, response data: #{response_data}")

      has_any_enrollment = currently_enrolled_schools.any?

      if !has_any_enrollment
        Rails.logger.info("[NscService] No current enrollments found for identity ID #{activity_flow.identity.id}")
        return EducationActivity.create!(
          activity_flow: activity_flow,
          school_name: nil,
          status: :not_enrolled
        )
      end

      EducationActivity.create!(
        activity_flow: activity_flow,
        school_name: currently_enrolled_schools.first,
        status: :enrolled
      )
    end

    # Maps NSC enrollment status to internal enum values
    # Enum values: 0=unknown, 1=not_enrolled, 2=enrolled
    def map_enrollment_status(status_code)
      case status_code
      when "CC"
        :enrolled
      when "CN"
        :not_enrolled
      else
        :unknown
      end
    end

    def parse_date(date_str)
      Date.parse(date_str) if date_str.present?
    rescue ArgumentError
      nil
    end
  end
end

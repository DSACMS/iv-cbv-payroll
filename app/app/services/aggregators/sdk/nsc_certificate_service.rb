# frozen_string_literal: true

require "openssl"

module Aggregators
  module Sdk
    class NscCertificateService
      DEFAULT_WARNING_DAYS = 30
      DEFAULT_CRITICAL_DAYS = 7

      class CertificateError < StandardError; end
      class CertificateExpiredError < CertificateError; end
      class CertificateExpiringSoonError < CertificateError; end
      class CertificateMissingError < CertificateError; end
      class CertificateInvalidError < CertificateError; end

      Result = Struct.new(
        :status,
        :days_remaining,
        :not_after,
        :not_before,
        :subject,
        :issuer,
        :serial,
        :error_message,
        keyword_init: true
      ) do
        def expired?
          status == :expired
        end

        def expiring_soon?
          status == :expiring_soon
        end

        def ok?
          status == :ok
        end

        def alert_needed?
          expired? || expiring_soon? || status == :invalid
        end
      end

      def initialize(environment: nil, logger: nil, cert_data: nil, cert_path: nil)
        @environment = (environment || ENV.fetch("NSC_ENVIRONMENT", "sandbox")).to_sym
        @logger = if logger
                    logger
                  elsif ENV.fetch("STRUCTURED_LOGGING_ENABLED", "false") == "true"
                    SemanticLogger["NscCertificateService"]
                  else
                    Rails.logger.tagged("NscCertificateService")
                  end
        @cert_data = cert_data
        @cert_path = cert_path
      end

      # Check certificate expiration and return a Result struct
      #
      # @param warning_days [Integer] Number of days before expiration to trigger warning (default 30)
      # @param critical_days [Integer] Number of days before expiration to trigger critical (default 7)
      # @return [Result]
      def check_expiration(warning_days: nil, critical_days: nil)
        warning_days ||= ENV.fetch("NSC_CERT_EXPIRATION_WARNING_DAYS", DEFAULT_WARNING_DAYS).to_i
        critical_days ||= ENV.fetch("NSC_CERT_EXPIRATION_CRITICAL_DAYS", DEFAULT_CRITICAL_DAYS).to_i

        cert_content = resolve_cert_content

        if cert_content.blank?
          return Result.new(
            status: :not_configured,
            days_remaining: nil,
            error_message: "No NSC client certificate configured"
          )
        end

        cert = parse_certificate(cert_content)
        not_after = cert.not_after
        not_before = cert.not_before
        now = Time.current
        days_remaining = ((not_after - now) / 1.day).to_f.round(1)

        status = if days_remaining <= 0
                   :expired
                 elsif days_remaining <= warning_days
                   :expiring_soon
                 else
                   :ok
                 end

        Result.new(
          status: status,
          days_remaining: days_remaining,
          not_after: not_after,
          not_before: not_before,
          subject: cert.subject.to_s,
          issuer: cert.issuer.to_s,
          serial: cert.serial.to_s(16)
        )
      rescue OpenSSL::X509::CertificateError => e
        Result.new(
          status: :invalid,
          days_remaining: nil,
          error_message: "Invalid certificate format: #{e.message}"
        )
      rescue => e
        Result.new(
          status: :error,
          days_remaining: nil,
          error_message: "Error reading certificate: #{e.message}"
        )
      end

      # Checks expiration, logs with structured tags, records telemetry, and triggers alerts
      #
      # @return [Result]
      def check_and_alert!(warning_days: nil, critical_days: nil)
        result = check_expiration(warning_days: warning_days, critical_days: critical_days)

        case result.status
        when :expired
          @logger.error("[NSC Client Cert EXPIRED] NSC client certificate EXPIRED on #{result.not_after} (#{result.days_remaining.abs} days ago). Subject: #{result.subject}, Issuer: #{result.issuer}. Action required: immediate renewal.")
          record_telemetry(result)
          notice_cert_error(CertificateExpiredError.new("NSC client certificate expired on #{result.not_after}"), result)
        when :expiring_soon
          @logger.warn("[NSC Client Cert EXPIRING SOON] NSC client certificate expires on #{result.not_after} (in #{result.days_remaining} days). Subject: #{result.subject}, Issuer: #{result.issuer}. Action required: renew before expiration.")
          record_telemetry(result)
          notice_cert_error(CertificateExpiringSoonError.new("NSC client certificate expires in #{result.days_remaining} days (on #{result.not_after})"), result)
        when :ok
          @logger.info("[NSC Client Cert OK] NSC client certificate is valid until #{result.not_after} (#{result.days_remaining} days remaining). Subject: #{result.subject}")
          record_telemetry(result)
        when :invalid
          @logger.error("[NSC Client Cert INVALID] #{result.error_message}")
          record_telemetry(result)
          notice_cert_error(CertificateInvalidError.new(result.error_message), result)
        when :not_configured
          @logger.info("[NSC Client Cert] No client certificate configured for #{@environment} environment.")
        end

        result
      end

      private

      def resolve_cert_content
        return @cert_data if @cert_data.present?

        if @cert_path.present? && File.exist?(@cert_path)
          return File.read(@cert_path)
        end

        env_cert = if @environment == :production
                     ENV["NSC_CLIENT_CERT"]
                   else
                     ENV["NSC_CLIENT_CERT_SANDBOX"] || ENV["NSC_CLIENT_CERT"]
                   end
        return env_cert if env_cert.present?

        env_cert_path = if @environment == :production
                          ENV["NSC_CLIENT_CERT_PATH"]
                        else
                          ENV["NSC_CLIENT_CERT_PATH_SANDBOX"] || ENV["NSC_CLIENT_CERT_PATH"]
                        end

        if env_cert_path.present? && File.exist?(env_cert_path)
          File.read(env_cert_path)
        end
      end

      def parse_certificate(content)
        OpenSSL::X509::Certificate.new(content)
      end

      def record_telemetry(result)
        return unless defined?(NewRelic::Agent)

        if result.days_remaining.present?
          NewRelic::Agent.record_metric("Custom/NSC/CertDaysUntilExpiration", result.days_remaining)
        end

        NewRelic::Agent.record_custom_event("NscClientCertExpiring", {
          status: result.status.to_s,
          days_remaining: result.days_remaining,
          expires_at: result.not_after&.iso8601,
          subject: result.subject,
          issuer: result.issuer,
          environment: @environment.to_s
        })
      end

      def notice_cert_error(error, result)
        return unless defined?(NewRelic::Agent)

        NewRelic::Agent.notice_error(error, custom_params: {
          status: result.status,
          days_remaining: result.days_remaining,
          expires_at: result.not_after&.iso8601,
          subject: result.subject,
          environment: @environment
        })
      end
    end
  end
end

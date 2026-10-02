# frozen_string_literal: true

# Paste this into a fresh Rails console inside PR 2075's CMS review task.
# Only the synthetic client's HTTP transport is replaced; deployed credentials
# and the application processes are untouched. No enrollment request is sent.
raise "Run inside PR 2075's review task" unless ENV["DOMAIN_NAME"] == "pr-2075.dev.emmy.cms.gov"
raise "Unexpected New Relic application" unless Array(NewRelic::Agent.config[:app_name]).include?("Iv Cbv Payroll (Dev)")

NewRelic::Agent.manual_start(agent_enabled: true, monitor_mode: true, sync_startup: true)

begin
  synthetic_key = OpenSSL::PKey::RSA.new(2048)
  synthetic_cert = OpenSSL::X509::Certificate.new
  synthetic_cert.version = 2
  synthetic_cert.serial = 2075
  synthetic_cert.subject = OpenSSL::X509::Name.parse("/CN=synthetic-nsc-alert-test")
  synthetic_cert.issuer = synthetic_cert.subject
  synthetic_cert.public_key = synthetic_key.public_key
  synthetic_cert.not_before = 1.day.ago
  synthetic_cert.not_after = 14.days.from_now
  synthetic_cert.sign(synthetic_key, OpenSSL::Digest::SHA256.new)

  # Exercise the real HTTP error handler and enrollment failure counter.
  synthetic_http_class = Class.new do
    def start
      yield self
    end

    def request(_request)
      Struct.new(:code, :body).new("503", "Synthetic NSC alert verification failure")
    end
  end
  synthetic_client_class = Class.new(Aggregators::Sdk::NscFdshService) do
    define_method(:build_http) { |_uri| synthetic_http_class.new }
  end
  synthetic_client = synthetic_client_class.new(
    base_url: "https://synthetic.invalid",
    token_url: "https://synthetic.invalid/token",
    client_id: "synthetic-client", client_secret: "synthetic-secret",
    client_cert: synthetic_cert, client_key: synthetic_key
  )
  begin
    synthetic_client.fetch_enrollment_data(
      first_name: "Synthetic", last_name: "AlertTest",
      date_of_birth: Date.new(1990, 1, 1), as_of_date: Date.current
    )
    raise "Expected the synthetic HTTP 503 to fail"
  rescue Aggregators::Sdk::NscFdshService::ApiError
    puts "Synthetic FDSH failure exercised; Custom/NSC/Failure incremented."
  end

  # Exercise the same certificate service used by NscCertificateCheckJob.
  synthetic_result = Aggregators::Sdk::NscCertificateService.new(
    cert_data: synthetic_cert.to_pem
  ).check_and_alert!(warning_days: 30)
  raise "Expected an expiration warning" unless synthetic_result.expiring_soon?
  puts "Synthetic CertificateExpiringSoonError reported."
ensure
  # Flush this console's telemetry before closing it.
  NewRelic::Agent.shutdown
end

puts "Check New Relic for BOTH incidents and their notifications; this output does not confirm delivery."

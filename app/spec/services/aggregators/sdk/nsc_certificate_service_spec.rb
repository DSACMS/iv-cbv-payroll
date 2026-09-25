# frozen_string_literal: true

require "rails_helper"
require "openssl"

RSpec.describe Aggregators::Sdk::NscCertificateService, type: :service do
  let(:logger) { Logger.new(StringIO.new) }
  let(:log_output) { StringIO.new }
  let(:test_logger) { Logger.new(log_output) }

  def generate_cert(not_before:, not_after:, common_name: "nsc-client-test")
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 12345
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{common_name}/O=CMS/OU=Emmy")
    cert.issuer = OpenSSL::X509::Name.parse("/CN=CMS-Test-CA")
    cert.public_key = key.public_key
    cert.not_before = not_before
    cert.not_after = not_after
    cert.sign(key, OpenSSL::Digest::SHA256.new)
    cert.to_pem
  end

  before do
    allow(NewRelic::Agent).to receive(:record_metric)
    allow(NewRelic::Agent).to receive(:record_custom_event)
    allow(NewRelic::Agent).to receive(:notice_error)
  end

  describe "#check_expiration" do
    context "when certificate is valid and not expiring soon (> 30 days)" do
      let(:cert_pem) { generate_cert(not_before: 10.days.ago, not_after: 60.days.from_now) }
      let(:service) { described_class.new(environment: :test, logger: test_logger, cert_data: cert_pem) }

      it "returns status :ok with remaining days" do
        result = service.check_expiration
        expect(result.status).to eq(:ok)
        expect(result.days_remaining).to be > 30
        expect(result.ok?).to be true
        expect(result.alert_needed?).to be false
        expect(result.subject).to include("nsc-client-test")
      end
    end

    context "when certificate is expiring soon (<= 30 days)" do
      let(:cert_pem) { generate_cert(not_before: 10.days.ago, not_after: 15.days.from_now) }
      let(:service) { described_class.new(environment: :test, logger: test_logger, cert_data: cert_pem) }

      it "returns status :expiring_soon" do
        result = service.check_expiration
        expect(result.status).to eq(:expiring_soon)
        expect(result.days_remaining).to be <= 30
        expect(result.expiring_soon?).to be true
        expect(result.alert_needed?).to be true
      end
    end

    context "when certificate is expired" do
      let(:cert_pem) { generate_cert(not_before: 40.days.ago, not_after: 5.days.ago) }
      let(:service) { described_class.new(environment: :test, logger: test_logger, cert_data: cert_pem) }

      it "returns status :expired" do
        result = service.check_expiration
        expect(result.status).to eq(:expired)
        expect(result.days_remaining).to be <= 0
        expect(result.expired?).to be true
        expect(result.alert_needed?).to be true
      end
    end

    context "when certificate content is invalid" do
      let(:service) { described_class.new(environment: :test, logger: test_logger, cert_data: "NOT_A_CERTIFICATE") }

      it "returns status :invalid with error message" do
        result = service.check_expiration
        expect(result.status).to eq(:invalid)
        expect(result.error_message).to be_present
        expect(result.alert_needed?).to be true
      end
    end

    context "when no certificate is configured" do
      let(:service) { described_class.new(environment: :test, logger: test_logger, cert_data: nil) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("NSC_CLIENT_CERT").and_return(nil)
        allow(ENV).to receive(:[]).with("NSC_CLIENT_CERT_SANDBOX").and_return(nil)
        allow(ENV).to receive(:[]).with("NSC_CLIENT_CERT_PATH").and_return(nil)
        allow(ENV).to receive(:[]).with("NSC_CLIENT_CERT_PATH_SANDBOX").and_return(nil)
      end

      it "returns status :not_configured" do
        result = service.check_expiration
        expect(result.status).to eq(:not_configured)
        expect(result.alert_needed?).to be false
      end
    end
  end

  describe "#check_and_alert!" do
    context "when certificate is valid" do
      let(:cert_pem) { generate_cert(not_before: 10.days.ago, not_after: 60.days.from_now) }
      let(:service) { described_class.new(environment: :test, logger: test_logger, cert_data: cert_pem) }

      it "logs OK message and records telemetry without error notification" do
        result = service.check_and_alert!
        expect(result.ok?).to be true
        expect(log_output.string).to include("[NSC Client Cert OK]")
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/NSC/CertDaysUntilExpiration", an_instance_of(Float))
        expect(NewRelic::Agent).to have_received(:record_custom_event)
          .with("NscClientCertExpiring", hash_including(status: "ok"))
        expect(NewRelic::Agent).not_to have_received(:notice_error)
      end
    end

    context "when certificate is expiring soon" do
      let(:cert_pem) { generate_cert(not_before: 10.days.ago, not_after: 14.days.from_now) }
      let(:service) { described_class.new(environment: :test, logger: test_logger, cert_data: cert_pem) }

      it "logs EXPIRING SOON warning, records telemetry, and notifies New Relic for alerting" do
        result = service.check_and_alert!
        expect(result.expiring_soon?).to be true
        expect(log_output.string).to include("[NSC Client Cert EXPIRING SOON]")
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/NSC/CertDaysUntilExpiration", an_instance_of(Float))
        expect(NewRelic::Agent).to have_received(:record_custom_event)
          .with("NscClientCertExpiring", hash_including(status: "expiring_soon"))
        expect(NewRelic::Agent).to have_received(:notice_error)
          .with(instance_of(Aggregators::Sdk::NscCertificateService::CertificateExpiringSoonError), hash_including(custom_params: hash_including(status: :expiring_soon)))
      end
    end

    context "when certificate is expired" do
      let(:cert_pem) { generate_cert(not_before: 40.days.ago, not_after: 2.days.ago) }
      let(:service) { described_class.new(environment: :test, logger: test_logger, cert_data: cert_pem) }

      it "logs EXPIRED error, records telemetry, and notifies New Relic with expired error" do
        result = service.check_and_alert!
        expect(result.expired?).to be true
        expect(log_output.string).to include("[NSC Client Cert EXPIRED]")
        expect(NewRelic::Agent).to have_received(:record_metric)
          .with("Custom/NSC/CertDaysUntilExpiration", an_instance_of(Float))
        expect(NewRelic::Agent).to have_received(:record_custom_event)
          .with("NscClientCertExpiring", hash_including(status: "expired"))
        expect(NewRelic::Agent).to have_received(:notice_error)
          .with(instance_of(Aggregators::Sdk::NscCertificateService::CertificateExpiredError), hash_including(custom_params: hash_including(status: :expired)))
      end
    end

    context "when certificate is loaded from file path" do
      let(:cert_pem) { generate_cert(not_before: 5.days.ago, not_after: 50.days.from_now) }
      let(:temp_cert_file) { Tempfile.new([ "nsc_cert", ".pem" ]) }

      before do
        temp_cert_file.write(cert_pem)
        temp_cert_file.flush
      end

      after do
        temp_cert_file.close
        temp_cert_file.unlink
      end

      it "reads certificate from file and checks expiration" do
        service = described_class.new(environment: :test, logger: test_logger, cert_path: temp_cert_file.path)
        result = service.check_and_alert!
        expect(result.ok?).to be true
        expect(log_output.string).to include("[NSC Client Cert OK]")
      end
    end
  end
end

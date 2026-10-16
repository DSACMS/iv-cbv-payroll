# frozen_string_literal: true

require "rails_helper"
require "fugit"

RSpec.describe NscCertificateCheckJob, type: :job do
  it "schedules a daily certificate check at 13:00 UTC" do
    recurring_tasks = YAML.load_file(Rails.root.join("config/recurring.yml"))
    task = recurring_tasks.fetch("production").fetch("check_nsc_certificate")

    expect(task.fetch("class")).to eq(described_class.name)
    schedule = Fugit.parse(task.fetch("schedule"))
    expect(schedule.next_time(Time.utc(2026, 10, 1, 12)).to_t).to eq(Time.utc(2026, 10, 1, 13))
    expect(schedule.next_time(Time.utc(2026, 10, 1, 14)).to_t).to eq(Time.utc(2026, 10, 2, 13))
  end

  describe "#perform" do
    let(:cert_service) { instance_double(Aggregators::Sdk::NscCertificateService) }

    it "calls check_and_alert! on NscCertificateService" do
      allow(Aggregators::Sdk::NscCertificateService).to receive(:new).and_return(cert_service)
      expect(cert_service).to receive(:check_and_alert!)

      described_class.perform_now
    end

    it "reports the certificate warning to New Relic using the CMS certificate" do
      key = OpenSSL::PKey::RSA.new(2048)
      certificate = OpenSSL::X509::Certificate.new
      certificate.serial = 1
      certificate.subject = OpenSSL::X509::Name.parse("/CN=synthetic-client")
      certificate.issuer = certificate.subject
      certificate.public_key = key.public_key
      certificate.not_before = 1.day.ago
      certificate.not_after = 14.days.from_now
      certificate.sign(key, OpenSSL::Digest::SHA256.new)
      allow(NewRelic::Agent).to receive(:record_metric)
      allow(NewRelic::Agent).to receive(:record_custom_event)
      allow(NewRelic::Agent).to receive(:notice_error)

      ClimateControl.modify(HUB_CERT: certificate.to_pem, HUB_CERT_PATH: nil, NSC_CERT_EXPIRATION_WARNING_DAYS: "30") do
        described_class.perform_now
      end

      expect(NewRelic::Agent).to have_received(:notice_error).with(
        instance_of(Aggregators::Sdk::NscCertificateService::CertificateExpiringSoonError),
        hash_including(custom_params: hash_including(status: :expiring_soon))
      ).once
      expect(NewRelic::Agent).not_to have_received(:notice_error).with(
        instance_of(Aggregators::Sdk::NscCertificateService::CertificateExpiredError), anything
      )
    end
  end
end

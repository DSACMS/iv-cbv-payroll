# frozen_string_literal: true

require "rails_helper"

RSpec.describe NscCertificateCheckJob, type: :job do
  describe "#perform" do
    let(:cert_service) { instance_double(Aggregators::Sdk::NscCertificateService) }

    it "calls check_and_alert! on NscCertificateService" do
      allow(Aggregators::Sdk::NscCertificateService).to receive(:new).and_return(cert_service)
      expect(cert_service).to receive(:check_and_alert!)

      described_class.perform_now
    end
  end
end

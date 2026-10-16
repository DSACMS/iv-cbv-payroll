# frozen_string_literal: true

require "rails_helper"
require "rake"

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Rake::Task, "#execute" do
  around do |example|
    original_rake_application = Rake.application
    Rake.application = Rake::Application.new

    load Rails.root.join("lib/tasks/nsc.rake")
    described_class.define_task(:environment)
    example.run
  ensure
    Rake.application = original_rake_application
  end

  describe "nsc:check_certificate" do
    let(:cert_service) { instance_double(Aggregators::Sdk::NscCertificateService) }

    before do
      allow(Aggregators::Sdk::NscCertificateService).to receive(:new).and_return(cert_service)
      allow(cert_service).to receive(:check_and_alert!)
    end

    it "invokes check_and_alert! on NscCertificateService" do
      described_class["nsc:check_certificate"].execute

      expect(cert_service).to have_received(:check_and_alert!)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat

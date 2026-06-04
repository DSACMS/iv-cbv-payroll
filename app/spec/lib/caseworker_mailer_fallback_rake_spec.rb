require "rails_helper"
require "rake"

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Rake::Task, "#execute" do
  around do |example|
    original_rake_application = Rake.application
    Rake.application = Rake::Application.new

    load Rails.root.join("lib/tasks/caseworker_mailer_fallback.rake")
    described_class.define_task(:environment)
    example.run
  ensure
    Rake.application = original_rake_application
  end

  describe "caseworker_mailer_fallback:preview" do
    let(:service) { instance_double(CaseworkerMailerFallbackService, preview: { count: 0, entries: [] }) }

    before do
      allow(CaseworkerMailerFallbackService).to receive(:new).and_return(service)
      allow($stdout).to receive(:puts)
    end

    it "previews all failures when no filter is provided" do
      described_class["caseworker_mailer_fallback:preview"].execute

      expect(service).to have_received(:preview).with(filter_name: nil)
    end

    it "passes the named filter when one is provided" do
      described_class["caseworker_mailer_fallback:preview"].execute(mode: "la_ldh_schema_error")

      expect(service).to have_received(:preview).with(filter_name: "la_ldh_schema_error")
    end
  end

  describe "caseworker_mailer_fallback:deliver_all" do
    let(:service) { instance_double(CaseworkerMailerFallbackService, deliver_all: { sent: 0, skipped: [] }) }

    before do
      allow(CaseworkerMailerFallbackService).to receive(:new).and_return(service)
      allow($stdout).to receive(:puts)
    end

    it "delivers all failures when no filter is provided" do
      described_class["caseworker_mailer_fallback:deliver_all"].execute

      expect(service).to have_received(:deliver_all).with(filter_name: nil)
    end

    it "passes the named filter when one is provided" do
      described_class["caseworker_mailer_fallback:deliver_all"].execute(mode: "la_ldh_schema_error")

      expect(service).to have_received(:deliver_all).with(filter_name: "la_ldh_schema_error")
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat

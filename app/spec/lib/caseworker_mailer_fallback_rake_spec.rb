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

    context "when the preview result includes a warning" do
      let(:service) do
        instance_double(
          CaseworkerMailerFallbackService,
          preview: {
            count: 1,
            entries: [
              {
                status: :sendable,
                cbv_flow: instance_double(CbvFlow),
                cbv_flow_id: 123,
                agency_id: "la_ldh",
                fallback_email: "fallback@example.gov",
                case_number: "ABC123",
                transmitted: "not yet sent",
                warning: "applicant is redacted",
                error: "Some error"
              }
            ]
          }
        )
      end

      it "prints the warning" do
        described_class["caseworker_mailer_fallback:preview"].execute

        expect($stdout).to have_received(:puts).with("  warning: applicant is redacted")
      end
    end
  end

  describe "caseworker_mailer_fallback:deliver_all" do
    let(:service) { instance_double(CaseworkerMailerFallbackService, deliver_all: { sent: 0, skipped: [], warnings: [] }) }

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

    context "when the deliver result includes a warning" do
      let(:service) do
        instance_double(
          CaseworkerMailerFallbackService,
          deliver_all: { sent: 1, skipped: [], warnings: [ "cbv_flow_id=123: applicant is redacted" ] }
        )
      end

      it "prints the warning" do
        described_class["caseworker_mailer_fallback:deliver_all"].execute

        expect($stdout).to have_received(:puts).with("  Warning: cbv_flow_id=123: applicant is redacted")
      end

      it "includes the warning count in the summary" do
        described_class["caseworker_mailer_fallback:deliver_all"].execute

        expect($stdout).to have_received(:puts).with("\nSummary: 1 sent, 0 skipped, 1 warning(s)")
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat

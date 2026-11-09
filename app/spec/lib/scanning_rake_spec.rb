require "rails_helper"
require "rake"
require "open3"

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Rake::Task, "#execute" do
  around do |example|
    original_rake_application = Rake.application
    Rake.application = Rake::Application.new

    load Rails.root.join("lib/tasks/scanning.rake")
    described_class.define_task(:environment)
    example.run
  ensure
    Rake.application = original_rake_application
  end

  describe "npm:audit" do
    let(:task) { described_class["npm:audit"] }
    let(:status) { instance_double(Process::Status, success?: false, exitstatus: 1) }
    let(:stderr) { "" }
    let(:stdout) do
      {
        auditReportVersion: 2,
        vulnerabilities: { "happy-dom" => { severity: "high" } }
      }.to_json
    end

    before do
      allow(Open3).to receive(:capture3).with("npm audit --json").and_return([ stdout, stderr, status ])
    end

    context "when npm reports vulnerabilities" do
      it "exits with npm's failure status" do
        expect { task.execute }.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(1)
        }
      end
    end

    context "when npm reports no vulnerabilities" do
      let(:status) { instance_double(Process::Status, success?: true, exitstatus: 0) }
      let(:stdout) { { auditReportVersion: 2, vulnerabilities: {} }.to_json }

      it "completes the audit" do
        task.execute

        expect(Open3).to have_received(:capture3).with("npm audit --json")
      end
    end

    context "when the registry is unavailable" do
      let(:stderr) { "503 Service Unavailable" }
      let(:stdout) { { error: { code: "E503", summary: stderr } }.to_json }

      before do
        allow(Rails.logger).to receive(:info)
      end

      it "logs the registry outage" do
        task.execute

        expect(Rails.logger).to have_received(:info).with("Ignoring unavailable server")
      end
    end

    context "when npm reports another error" do
      let(:status) { instance_double(Process::Status, success?: false, exitstatus: 2) }
      let(:stdout) { { error: { code: "EUSAGE", summary: "Invalid audit configuration" } }.to_json }

      it "preserves npm's error status" do
        expect { task.execute }.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(2)
        }
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat

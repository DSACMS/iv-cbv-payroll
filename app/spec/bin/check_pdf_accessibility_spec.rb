require "rails_helper"
require "tmpdir"
require "open3"

# This spec exercises an executable script rather than a class.
RSpec.describe "bin/check-pdf-accessibility" do # rubocop:disable RSpec/DescribeClass
  let(:specification) { "ISO 14289-1:2014" }
  let(:rules) { [] }
  let(:compliant) { rules.empty? ? "true" : "false" }
  let(:job_status) { "normal" }
  let(:command_status) { instance_double(Process::Status, success?: true) }
  let(:report) do
    rule_xml = rules.map do |clause, number|
      %(<rule specification="#{specification}" clause="#{clause}" testNumber="#{number}" status="failed" />)
    end.join
    <<~XML
      <report><jobs><job>
        <validationReport jobEndStatus="#{job_status}" isCompliant="#{compliant}">
          <details failedRules="#{rules.length}">#{rule_xml}</details>
        </validationReport>
      </job></jobs></report>
    XML
  end

  around do |example|
    Dir.mktmpdir("pdf-validation-spec-") do |directory|
      ClimateControl.modify("PDF_ACCESSIBILITY_REPORT_DIR" => directory) { example.run }
    end
  end

  before do
    stub_const("ARGV", [ "/synthetic/report.pdf" ])
    allow(Open3).to receive(:capture3).and_return([ report, "", command_status ])
  end

  def run_check
    load Rails.root.join("bin/check-pdf-accessibility")
  end

  it "accepts compliant PDFs" do
    expect { run_check }.to output(/1 PDFs checked: 0 expected rule failures, no unexpected failures/).to_stdout
  end

  context "with all four accepted Chromium violations" do
    let(:rules) { [ [ "7.1", "3" ], [ "7.1", "8" ], [ "7.1", "5" ], [ "7.2", "20" ] ] }

    it "reports expected failures without claiming compliance" do
      expect { run_check }.to output(/4 expected rule failures.*This does not establish PDF\/UA compliance/m).to_stdout
    end

    it "preserves the original validation evidence" do
      run_check

      expect(File.read(File.join(ENV.fetch("PDF_ACCESSIBILITY_REPORT_DIR"), "verapdf.xml"))).to eq(report)
    end

    context "with a different specification" do
      let(:specification) { "another standard" }

      it "rejects rules from an unrecognized specification" do
        expect { run_check }.to raise_error(SystemExit)
      end
    end
  end

  context "with an unexpected violation alongside expected failures" do
    let(:rules) { [ [ "7.1", "8" ], [ "7.1", "99" ] ] }

    it "fails the check" do
      expect { run_check }.to raise_error(SystemExit)
    end
  end

  context "when veraPDF exits unsuccessfully" do
    let(:command_status) { instance_double(Process::Status, success?: false) }

    it "fails even with a compliant report" do
      expect { run_check }.to raise_error(SystemExit)
    end
  end

  context "with missing validation results" do
    let(:report) { "<report />" }

    it "fails the check" do
      expect { run_check }.to raise_error(SystemExit)
    end
  end

  context "with an abnormal validation result" do
    let(:job_status) { "failed" }

    it "fails the check" do
      expect { run_check }.to raise_error(SystemExit)
    end
  end

  context "with unexplained noncompliance" do
    let(:compliant) { "false" }

    it "rejects a noncompliant result without failed rules" do
      expect { run_check }.to raise_error(SystemExit)
    end
  end

  context "with malformed XML" do
    let(:report) { "<report>" }

    it "rejects the report" do
      expect { run_check }.to raise_error(REXML::ParseException)
    end
  end
end
